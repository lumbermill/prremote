i2c = I2C.new(unit: :RP2040_I2C0, sda_pin: 4, scl_pin: 5)
p i2c.scan   # => [0x3E] または [0x27] や [0x3F] など
