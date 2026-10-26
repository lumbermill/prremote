# Device: Raspberry Pi Pico / Pico W
# Scan the I2C bus and print progress while probing.
# Wiring: sensor SDA → GP4, SCL → GP5 (plus 3V3 and GND).
#
# Each address gets an address-only write, so write-only parts such as
# ST7032 LCDs (0x3E) are safe to scan. An absent address NACKs at once and a
# healthy bus scans in a few ms. If it takes seconds, check pins and pull-ups:
# timeout: caps the wait per address (default 500 ms).

i2c = I2C.new(unit: :I2C0, sda_pin: 4, scl_pin: 5)

found = i2c.scan(timeout: 20) do |addr, ok|
  puts "  0x#{addr.to_s(16)} found" if ok
  puts "... 0x#{addr.to_s(16)}" if addr % 16 == 0
end
p found # => [0x3E] or [0x27] / [0x3F] etc.
