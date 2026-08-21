# Device: M5StickC PLUS (ESP32-PICO-D4)
# LCD hello world — no wiring needed (internal ST7789v2 panel, 135x240).
# Unlike M5GO, the backlight is not a GPIO PWM pin: the AXP192 PMIC (I2C
# address 0x34) must enable LDO2 (backlight) / LDO3 (panel power) first, or
# the panel stays dark even though the SPI writes below succeed.
i2c = I2C.new(sda_pin: 21, scl_pin: 22)
i2c.write(0x34, 0x28, 0xCC)                 # LDO2/LDO3 voltage = 3.0V
cur = i2c.read(0x34, 1, 0x12).getbyte(0)
i2c.write(0x34, 0x12, cur | 0x4D)           # enable Ext, LDO2, LDO3, DCDC1

# Pin defaults in LCD.new match the M5GO (M5Stack Core); M5StickC PLUS wires
# its ST7789v2 differently and needs width/height/offset_x/offset_y because
# the 135x240 visible area sits inside a larger 240x320 controller RAM
# window. madctl: 0x00 drops the BGR bit the default table sets for the
# ILI9342C (M5GO) — this ST7789 wants plain RGB. Without this override red
# text rendered blue on physical hardware; red/green/blue test text with
# the bit dropped came out correct (green read very slightly yellowish,
# which looks like normal panel color response, not a channel swap).
lcd = LCD.new(sck_pin: 13, mosi_pin: 15, miso_pin: -1, cs_pin: 5, dc_pin: 23,
              rst_pin: 18, bl_pin: -1, invert: true, madctl: 0x00,
              width: 135, height: 240, offset_x: 52, offset_y: 40)
lcd.fill(LCD::BLACK)
lcd.text(4, 40, "Hello", color: LCD::WHITE, scale: 2)
lcd.text(4, 70, "from Ruby!", color: LCD::WHITE, scale: 1)
lcd.text(4, 100, "M5StickC PLUS", color: LCD::CYAN, scale: 1)
lcd.fill_rect(4, 130, 120, 4, LCD::ORANGE)
puts "drawn #{lcd.width}x#{lcd.height}"
