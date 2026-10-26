# Device: Seeed Studio XIAO ESP32C6
# Scan the I2C bus on XIAO's dedicated I2C pins, printing progress.
# Wiring: sensor SDA → D4 (GPIO 22), SCL → D5 (GPIO 23).
#
# The block runs after each probe. timeout: caps the wait per address
# (default 500 ms); a healthy bus never hits it because absent devices NACK.

i2c = I2C.new(sda_pin: 22, scl_pin: 23)
found = i2c.scan(timeout: 20) do |addr, ok|
  puts "  0x#{addr.to_s(16)} found" if ok
  puts "... 0x#{addr.to_s(16)}" if addr % 16 == 0
end
if found.empty?
  puts "No I2C devices found."
else
  puts "Found #{found.size} device(s):"
  found.each { |addr| puts "  0x#{addr.to_s(16)}" }
end
