# Device: M5StickC PLUS (ESP32-PICO-D4)
# A joke sample: "Fablab" filling the screen, rotated 90° clockwise (hold
# the stick upright, text reads top-to-bottom). Press button A to blink the
# text to a new color; press button B to blink the background instead —
# handy as a visual "which button did I just press?" check.
#
# Wiring: none — everything built-in. See lcd_hello.rb for the AXP192
# power-on this panel needs before it'll show anything.

i2c = I2C.new(sda_pin: 21, scl_pin: 22)
i2c.write(0x34, 0x28, 0xCC)                 # LDO2/LDO3 voltage = 3.0V
cur = i2c.read(0x34, 1, 0x12).getbyte(0)
i2c.write(0x34, 0x12, cur | 0x4D)           # enable Ext, LDO2, LDO3, DCDC1

# rotation: 3 is what "90° clockwise" turned out to mean on this panel —
# rotation: 1 read upside down. Landscape swaps LCD#width/#height to 240x135.
lcd = LCD.new(rotation: 3, sck_pin: 13, mosi_pin: 15, miso_pin: -1, cs_pin: 5,
              dc_pin: 23, rst_pin: 18, bl_pin: -1, invert: true,
              width: 135, height: 240, offset_x: 52, offset_y: 40)

btn_a = GPIO.new(37, GPIO::IN)
btn_b = GPIO.new(39, GPIO::IN)

FG_COLORS = [LCD::CYAN, LCD::YELLOW, LCD::MAGENTA, LCD::GREEN, LCD::ORANGE, LCD::WHITE, LCD::RED]
BG_COLORS = [LCD::BLACK, LCD::BLUE]
TEXT      = "Fablab"
SCALE     = 4
CELL      = 8 * SCALE
X = (lcd.width  - TEXT.length * CELL) / 2
Y = (lcd.height - CELL) / 2

def show(lcd, fg, bg)
  lcd.fill(bg)
  lcd.text(X, Y, TEXT, color: fg, bg: bg, scale: SCALE)
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
    blink(lcd, FG_COLORS[fg_idx], FG_COLORS[fg_idx], BG_COLORS[bg_idx])
    sleep 0.05 while btn_b.read == 0
  end
  sleep 0.02
end
