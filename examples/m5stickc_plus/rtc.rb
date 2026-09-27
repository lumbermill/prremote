# Device: M5StickC PLUS (ESP32-PICO-D4)
# Read the built-in BM8563 real-time clock over I2C — no wiring needed
# (address 0x51, same bus as the AXP192/MPU6886: SDA=GPIO21/SCL=GPIO22).
# The RTC keeps running from the internal battery while the board is off,
# so after rtc_sync.rb has set it once, this prints the correct local time
# even without WiFi.
#
# Register map (PCF8563-compatible, all values BCD):
#   0x02 sec (bit7 = VL: clock integrity lost), 0x03 min, 0x04 hour,
#   0x05 day, 0x06 weekday (0 = Sun), 0x07 month (bit7 = century), 0x08 year

RTC_ADDR = 0x51
WDAYS = %w[Sun Mon Tue Wed Thu Fri Sat]

def bcd2dec(b)
  ((b >> 4) * 10) + (b & 0x0F)
end

def p2(n)
  n < 10 ? "0#{n}" : n.to_s
end

i2c = I2C.new(sda_pin: 21, scl_pin: 22)

puts "BM8563 RTC (reading for 10 s)..."
10.times do
  r = i2c.read(RTC_ADDR, 7, 0x02).bytes
  sec   = bcd2dec(r[0] & 0x7F)
  min   = bcd2dec(r[1] & 0x7F)
  hour  = bcd2dec(r[2] & 0x3F)
  day   = bcd2dec(r[3] & 0x3F)
  wday  = r[4] & 0x07
  month = bcd2dec(r[5] & 0x1F)
  year  = bcd2dec(r[6]) + (r[5] < 0x80 ? 2000 : 1900) # bit7 = century

  line = "#{year}-#{p2(month)}-#{p2(day)} (#{WDAYS[wday]}) #{p2(hour)}:#{p2(min)}:#{p2(sec)}"
  line += "  [VL: time invalid — run rtc_sync.rb]" if r[0] >= 0x80 # bit7 = VL
  puts line
  sleep 1
end
