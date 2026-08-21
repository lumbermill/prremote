# Device: M5StickC PLUS (ESP32-PICO-D4)
# A joke sample: "Fablab" filling the screen, rotated 90° clockwise (hold
# the stick upright, text reads top-to-bottom). Press button A to blink to
# a new color.
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

COLORS = [LCD::CYAN, LCD::YELLOW, LCD::MAGENTA, LCD::GREEN, LCD::ORANGE, LCD::WHITE, LCD::RED]
TEXT   = "Fablab"
SCALE  = 4
CELL   = 8 * SCALE
X = (lcd.width  - TEXT.length * CELL) / 2
Y = (lcd.height - CELL) / 2

def show(lcd, color)
  lcd.fill(LCD::BLACK)
  lcd.text(X, Y, TEXT, color: color, scale: SCALE)
end

def blink(lcd, color)
  3.times do
    lcd.fill(color)
    sleep 0.08
    lcd.fill(LCD::BLACK)
    sleep 0.08
  end
  show(lcd, color)
end

idx = 0
show(lcd, COLORS[idx])

loop do
  if btn_a.read == 0
    idx = (idx + 1) % COLORS.length
    blink(lcd, COLORS[idx])
    sleep 0.05 while btn_a.read == 0 # wait for release (debounce)
  end
  sleep 0.02
end
