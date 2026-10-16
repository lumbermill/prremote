# Device: M5StickC PLUS (ESP32-PICO-D4)
# Read the built-in BM8563 real-time clock — no wiring needed.
# The RTC keeps running from the internal battery while the board is off,
# so after rtc_sync.rb has set it once, this prints the correct local time
# even without WiFi.
#
# stick.rtc is a BM8563 (board library, see lcd_hello.rb); #time returns the
# runtime's Time class, JST (UTC+9) unless given time(offset: N).

stick = M5StickCPlus.new
rtc = stick.rtc

puts "BM8563 RTC (reading for 10 s)..."
puts "not set yet (or the backup battery ran out) — run rtc_sync.rb" unless rtc.valid?
10.times do
  puts rtc.time.to_s
  sleep 1
end
