# Device: M5StickC PLUS (ESP32-PICO-D4)
# "Ruby" with a small gem icon, filling the screen, rotated 90° clockwise
# (hold the stick upright, text reads top-to-bottom) — a fablab.rb variant.
# Press button A to blink the text to a new color; press button B to blink
# the background instead.
#
# Wiring: none — everything built-in. See lcd_hello.rb for the AXP192
# power-on this panel needs before it'll show anything.

i2c = I2C.new(sda_pin: 21, scl_pin: 22)
i2c.write(0x34, 0x28, 0xCC)                 # LDO2/LDO3 voltage = 3.0V
cur = i2c.read(0x34, 1, 0x12).getbyte(0)
i2c.write(0x34, 0x12, cur | 0x4D)           # enable Ext, LDO2, LDO3, DCDC1

# rotation: 3 = "90° clockwise" on this panel; madctl: 0xA0 drops the BGR
# bit the default table assumes for the ILI9342C (M5GO) — see lcd_hello.rb.
lcd = LCD.new(rotation: 3, sck_pin: 13, mosi_pin: 15, miso_pin: -1, cs_pin: 5,
              dc_pin: 23, rst_pin: 18, bl_pin: -1, invert: true, madctl: 0xA0,
              width: 135, height: 240, offset_x: 52, offset_y: 40)

btn_a = GPIO.new(37, GPIO::IN)
btn_b = GPIO.new(39, GPIO::IN)

FG_COLORS = [LCD::RED, LCD::CYAN, LCD::YELLOW, LCD::MAGENTA, LCD::GREEN, LCD::ORANGE, LCD::WHITE]
BG_COLORS = [LCD::BLACK, LCD::BLUE]
TEXT      = "Ruby"
SCALE     = 4
CELL      = 8 * SCALE
SUB       = "by prremote"
SUB_SCALE = 1
SUB_CELL  = 8 * SUB_SCALE
GAP = 10

ICON_W   = 32
ICON_H   = 24
ICON_GAP = 8

TEXT_W = TEXT.length * CELL
ROW_W  = ICON_W + ICON_GAP + TEXT_W
ROW_X  = (lcd.width - ROW_W) / 2
ICON_X = ROW_X
TEXT_X = ROW_X + ICON_W + ICON_GAP

Y      = (lcd.height - (CELL + GAP + SUB_CELL)) / 2
Y2     = Y + CELL + GAP
ICON_Y = Y + ((CELL - ICON_H) / 2)
X2     = (lcd.width - (SUB.length * SUB_CELL)) / 2

# Small faceted gem: flat top crown widening to the shoulder, then
# tapering to a point — same idea as the ntp_clock.rb (M5GO) logo, halved.
def draw_gem(lcd, x, y, color)
  lcd.fill_rect(x + 10, y,      12, 3, color)
  lcd.fill_rect(x + 6,  y + 3,  20, 3, color)
  lcd.fill_rect(x + 2,  y + 6,  28, 5, color)
  lcd.fill_rect(x + 4,  y + 11, 24, 4, color)
  lcd.fill_rect(x + 8,  y + 15, 16, 4, color)
  lcd.fill_rect(x + 12, y + 19, 8,  3, color)
  lcd.fill_rect(x + 14, y + 22, 4,  2, color)
end

def show(lcd, fg, bg)
  lcd.fill(bg)
  draw_gem(lcd, ICON_X, ICON_Y, fg)
  lcd.text(TEXT_X, Y, TEXT, color: fg, bg: bg, scale: SCALE)
  lcd.text(X2, Y2, SUB, color: fg, bg: bg, scale: SUB_SCALE)
end

def blink(lcd, flash, fg, bg)
  3.times do
    lcd.fill(flash)
    sleep 0.08
    lcd.fill(bg)
    sleep 0.08
  end
  show(lcd, fg, bg)
end

fg_idx = 0
bg_idx = 0
show(lcd, FG_COLORS[fg_idx], BG_COLORS[bg_idx])

loop do
  if btn_a.read == 0
    fg_idx = (fg_idx + 1) % FG_COLORS.length
    blink(lcd, FG_COLORS[fg_idx], FG_COLORS[fg_idx], BG_COLORS[bg_idx])
    sleep 0.05 while btn_a.read == 0 # wait for release (debounce)
  elsif btn_b.read == 0
    bg_idx = (bg_idx + 1) % BG_COLORS.length
    blink(lcd, BG_COLORS[bg_idx], FG_COLORS[fg_idx], BG_COLORS[bg_idx])
    sleep 0.05 while btn_b.read == 0
  end
  sleep 0.02
end
