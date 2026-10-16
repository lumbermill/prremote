# Device: M5StickC PLUS (ESP32-PICO-D4)
# Set the built-in BM8563 RTC from NTP, then read it back.
# After this, rtc.rb shows the correct time without WiFi — the RTC keeps
# counting on the internal battery while the board is powered off.
#
# Wiring: none. Set SSID and PASSWORD before running.
# The RTC holds local time (JST = UTC+9 here); change OFFSET for other zones.

SSID     = "MySSID"
PASSWORD = "MyPassword"
OFFSET   = 9

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

rtc = M5StickCPlus.new.rtc
rtc.time = t
puts "RTC:  #{rtc.time(offset: OFFSET).to_s}"
puts rtc.valid? ? "OK: RTC set" : "NG: RTC still reports invalid time"
