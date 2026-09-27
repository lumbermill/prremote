# Device: M5StickC PLUS (ESP32-PICO-D4)
# Set the built-in BM8563 RTC (I2C 0x51) from NTP, then read it back.
# After this, rtc.rb shows the correct time without WiFi — the RTC keeps
# counting on the internal battery while the board is powered off.
#
# Wiring: none. Set SSID and PASSWORD before running.
# The RTC holds local time (JST = UTC+9 here); change OFFSET for other zones.

SSID     = "MySSID"
PASSWORD = "MyPassword"
OFFSET   = 9
RTC_ADDR = 0x51

def dec2bcd(n)
  ((n / 10) << 4) | (n % 10)
end

def bcd2dec(b)
  ((b >> 4) * 10) + (b & 0x0F)
end

WiFi.init
puts "Connecting to #{SSID}..."
begin
  WiFi.connect(SSID, PASSWORD, WiFi::Auth::WPA2_MIXED_PSK, 20)
rescue WiFi::ConnectError, WiFi::ConnectTimeout => e
  puts "WiFi failed: #{e.message}"
  return
end

t = Time.new(offset: OFFSET)
if t.sync("ntp.nict.jp", interval: 5, timeout: 60).nil?
  puts "NTP sync failed"
  return
end
puts "NTP:  #{t.to_s}"

# 1970-01-01 was a Thursday (weekday 4, Sunday = 0).
wday = (((t.epoch + (OFFSET * 3600)) / 86_400) + 4) % 7

i2c = I2C.new(sda_pin: 21, scl_pin: 22)
i2c.write(RTC_ADDR, 0x00, 0x00, 0x00) # control 1/2: clock running, no alarms/timer IRQ
i2c.write(RTC_ADDR, 0x02,
          dec2bcd(t.sec), dec2bcd(t.min), dec2bcd(t.hour), dec2bcd(t.day),
          wday, dec2bcd(t.month), dec2bcd(t.year % 100)) # century bit 0 = 20xx

r = i2c.read(RTC_ADDR, 7, 0x02).bytes
puts "RTC:  20#{bcd2dec(r[6])}-#{bcd2dec(r[5] & 0x1F)}-#{bcd2dec(r[3] & 0x3F)} " \
     "#{bcd2dec(r[2] & 0x3F)}:#{bcd2dec(r[1] & 0x7F)}:#{bcd2dec(r[0] & 0x7F)}"
puts r[0] < 0x80 ? "OK: RTC set" : "NG: VL flag still set" # bit7 = VL
