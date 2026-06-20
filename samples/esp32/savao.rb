# Device: M5GO / M5Stack Core (ESP32)
# SAVAO: a singing face — ANGLE SENSOR controls pitch and mouth opening.
# Wiring: ANGLE SENSOR → PORT B (Grove, black side connector)
#   Yellow wire → GPIO36 (ADC1_CH0, input-only). Speaker: built-in GPIO25.
# BtnA (GPIO39): mute / unmute    BtnB (GPIO38): invert colors    BtnC (GPIO37): exit
#
# Face layout on 320x240 LCD:
#   Left eye  ">": 3 lines from tip (120,85) → upper-left/left/lower-left
#   Right eye "<": 3 lines from tip (200,85) → upper-right/right/lower-right
#   Mouth: top fixed at y=175, bottom drops to y=239 at max opening

FREQ_MIN    = 200
FREQ_MAX    = 2000
SPEAKER_PIN = 25
VOLUME      = 1024  # PWM duty_u16 (0-65535); 1024≈1.6%, 2048≈3.1%, 4096≈6.3%
MOUTH_X     = 125   # left edge; LCD center (160) − half of MOUTH_W (35)
MOUTH_TOP_Y = 175   # fixed top of mouth
MOUTH_W     = 70
MOUTH_MIN_H = 4
MOUTH_MAX_H = 62    # bottom border reaches y=239 at full open (175+62+2=239)

def line_deltas(x0, y0, x1, y1)
  dx = x1 >= x0 ? x1 - x0 : x0 - x1
  dy = y1 >= y0 ? y1 - y0 : y0 - y1
  sx = x0 < x1 ? 1 : -1
  sy = y0 < y1 ? 1 : -1
  [dx, dy, sx, sy]
end

# Bresenham line — each point rendered as a 3x3 block for visibility.
# p0 = [x0, y0], p1 = [x1, y1]
def draw_line(lcd, p0, p1, color)
  x0, y0 = p0[0], p0[1]
  x1, y1 = p1[0], p1[1]
  dx, dy, sx, sy = line_deltas(x0, y0, x1, y1)
  err = dx - dy
  loop do
    lcd.fill_rect(x0, y0, 3, 3, color)
    break if x0 == x1 && y0 == y1

    e2 = err * 2
    if e2 >= -dy
      err -= dy
      x0  += sx
    end
    if e2 <= dx
      err += dx
      y0  += sy
    end
  end
end

def draw_face(lcd, fg)
  c = fg

  # Left eye ">": three lines radiating left from tip at (120,85)
  draw_line(lcd, [120, 85], [65,  55], c)  # upper-left
  draw_line(lcd, [120, 85], [55,  85], c)  # horizontal left
  draw_line(lcd, [120, 85], [65, 115], c)  # lower-left

  # Right eye "<": three lines radiating right from tip at (200,85)
  draw_line(lcd, [200, 85], [255,  55], c)  # upper-right
  draw_line(lcd, [200, 85], [265,  85], c)  # horizontal right
  draw_line(lcd, [200, 85], [255, 115], c)  # lower-right
end

def draw_mouth(lcd, mouth_h, fg)
  c = fg
  lcd.fill_rect(MOUTH_X,               MOUTH_TOP_Y,           MOUTH_W, 3,           c)  # top (fixed)
  lcd.fill_rect(MOUTH_X,               MOUTH_TOP_Y + mouth_h, MOUTH_W, 3,           c)  # bottom (moves)
  lcd.fill_rect(MOUTH_X,               MOUTH_TOP_Y,           3,       mouth_h + 3, c)  # left side
  lcd.fill_rect(MOUTH_X + MOUTH_W - 3, MOUTH_TOP_Y,           3,       mouth_h + 3, c)  # right side
end

def erase_mouth(lcd, bg)
  lcd.fill_rect(MOUTH_X - 1, MOUTH_TOP_Y - 1, MOUTH_W + 2, 241 - MOUTH_TOP_Y, bg)
end

lcd   = LCD.new
adc   = ADC.new(36)
btn_a = GPIO.new(39, GPIO::IN)
btn_b = GPIO.new(38, GPIO::IN)
btn_c = GPIO.new(37, GPIO::IN)
spk   = PWM.new(SPEAKER_PIN, frequency: FREQ_MIN, duty_u16: 0)

fg = LCD::BLACK
bg = LCD::WHITE

lcd.fill(bg)
draw_face(lcd, fg)
draw_mouth(lcd, MOUTH_MIN_H, fg)

inverted = false
muted    = false
prev_a   = 1
prev_b   = 1
prev_mh  = MOUTH_MIN_H

loop do
  break if btn_c.read == 0

  cur_a = btn_a.read
  if cur_a == 0 && prev_a == 1
    muted = !muted
    spk.duty_u16 = 0 if muted
  end
  prev_a = cur_a

  cur_b = btn_b.read
  if cur_b == 0 && prev_b == 1
    inverted = !inverted
    fg = inverted ? LCD::WHITE : LCD::BLACK
    bg = inverted ? LCD::BLACK : LCD::WHITE
    lcd.fill(bg)
    draw_face(lcd, fg)
    draw_mouth(lcd, prev_mh, fg)
  end
  prev_b = cur_b

  raw  = adc.read
  freq = FREQ_MIN + (raw * (FREQ_MAX - FREQ_MIN) / 65520)

  spk.frequency = freq
  spk.duty_u16  = muted ? 0 : VOLUME

  mouth_h = MOUTH_MIN_H + (raw * (MOUTH_MAX_H - MOUTH_MIN_H) / 65520)

  diff = mouth_h - prev_mh
  diff = -diff if diff < 0
  if diff > 2
    erase_mouth(lcd, bg)
    draw_mouth(lcd, mouth_h, fg)
    prev_mh = mouth_h
  end

  sleep 0.05
end

spk.duty_u16 = 0
lcd.fill(LCD::BLACK)
lcd.text(90, 108, "bye!", color: LCD::WHITE, scale: 3)
