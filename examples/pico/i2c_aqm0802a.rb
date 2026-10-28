# Device: Pico / Pico W — I2C character LCD (AQM0802A-RN-GBW, ST7032, 8x2)
# Wiring: SDA → GPIO 4, SCL → GPIO 5, VCC → 3.3V, GND → GND
# ST7032 I2C address: 0x3E (fixed)
# Board: https://akizukidenshi.com/catalog/g/g111753/
# The ST7032 is write-only: every transfer is a control byte
# (0x00 = command, 0x40 = data) followed by one value byte.

LCD_ADDR = 0x3E
LCD_CMD  = 0x00
LCD_DATA = 0x40

# Contrast 0..63. Raise it if the text is faint, lower it if the
# background cells show up as dark boxes.
CONTRAST = 0x20

i2c = I2C.new(unit: :RP2040_I2C0, sda_pin: 4, scl_pin: 5, frequency: 400_000)

def lcd_cmd(i2c, c)
  i2c.write(LCD_ADDR, LCD_CMD, c)
  sleep 0.001
end

def lcd_init(i2c)
  sleep 0.04                                   # wait for power-on reset
  lcd_cmd(i2c, 0x38)                           # function set: 8-bit, 2 lines
  lcd_cmd(i2c, 0x39)                           # function set: extended instructions
  lcd_cmd(i2c, 0x14)                           # internal OSC frequency
  lcd_cmd(i2c, 0x70 | (CONTRAST & 0x0F))       # contrast low 4 bits
  lcd_cmd(i2c, 0x54 | ((CONTRAST >> 4) & 0x03)) # booster on + contrast high 2 bits
  lcd_cmd(i2c, 0x6C)                           # follower circuit on
  sleep 0.2                                    # let the power stabilize
  lcd_cmd(i2c, 0x38)                           # back to normal instructions
  lcd_cmd(i2c, 0x0C)                           # display on, cursor off
  lcd_clear(i2c)
end

def lcd_clear(i2c)
  lcd_cmd(i2c, 0x01)
  sleep 0.002
end

# col 0..7, row 0..1 (DDRAM row 1 starts at 0x40)
def lcd_move(i2c, col, row)
  lcd_cmd(i2c, 0x80 | ((row == 0 ? 0x00 : 0x40) + col))
end

# ASCII only; one data transfer per character.
def lcd_print(i2c, text)
  i = 0
  while i < text.size
    i2c.write(LCD_ADDR, LCD_DATA, text.getbyte(i))
    i += 1
  end
end

lcd_init(i2c)
lcd_move(i2c, 0, 0)
lcd_print(i2c, "Hi Pico!")

count = 0
loop do
  lcd_move(i2c, 0, 1)
  lcd_print(i2c, sprintf("%4d sec", count))  # always 8 chars, so no clear needed
  count += 1
  sleep 1
end
