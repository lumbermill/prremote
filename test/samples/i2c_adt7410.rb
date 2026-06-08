# Device: Pico / Pico W — I2C temperature sensor (ADT7410)
# Wiring: SDA → GPIO 4, SCL → GPIO 5, VCC → 3.3V, GND → GND
# Pullup resistors (4.7kΩ) on SDA/SCL to 3.3V are required
# (many breakout boards include them).
# ADT7410 default I2C address: 0x48 (A1=A0=GND)

i2c = I2C.new(unit: :RP2040_I2C0, sda_pin: 4, scl_pin: 5, frequency: 400_000)

loop do
  # Write register pointer 0x00 (temperature MSB), then read 2 bytes.
  bytes = i2c.read(0x48, 2, 0x00)&.bytes
  if bytes
    raw = ((bytes[0] << 8) | bytes[1]) >> 3  # 13-bit value
    raw -= 8192 if raw >= 4096               # two's complement for negative temps
    puts "#{raw / 16.0} C"
  else
    puts "read error"
  end
  sleep 1
end
