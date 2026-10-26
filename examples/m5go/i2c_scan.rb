# Device: M5GO / M5Stack Core (ESP32)
# Scan the internal I2C bus — no wiring needed (SDA: GPIO21, SCL: GPIO22).
# Expected devices on an M5GO:
#   0x75 = IP5306 (battery / power management)
#   0x68 = MPU6886 or MPU9250 (IMU; model depends on the board revision)
#   0x10 = BMM150 magnetometer (older revisions only)
#
# The block runs after each probe, so progress shows while scanning.
# timeout: caps the wait per address (default 500 ms → up to ~56 s total).
i2c = I2C.new(sda_pin: 21, scl_pin: 22)
found = i2c.scan(timeout: 20) do |addr, ok|
  puts "  0x#{addr.to_s(16)} found" if ok
  puts "... 0x#{addr.to_s(16)}" if addr % 16 == 0
end
p found # => [16, 104, 117] etc. (0x10, 0x68, 0x75)
