# Device: M5StickC PLUS (ESP32-PICO-D4)
# Displays current time (JST = UTC+9) on the built-in LCD, updated every
# second. Syncs once per hour via SNTP.
#
# Wiring: none — WiFi and LCD are built-in (M5StickCPlus: see lcd_hello.rb).
# Set SSID and PASSWORD before deploying. For a clock that keeps time
# without WiFi, see rtc.rb / ruby.rb (built-in RTC).

SSID     = "MySSID"
PASSWORD = "MyPassword"

SYNC_INTERVAL = 3600
NTP_SERVER    = "ntp.nict.jp"

stick = M5StickCPlus.new
lcd = stick.lcd
lcd.fill(LCD::BLACK)
lcd.text(4, 4, "Connecting...", scale: 1)

WiFi.init
begin
  WiFi.connect(SSID, PASSWORD, WiFi::Auth::WPA2_MIXED_PSK, 20)
rescue WiFi::ConnectError
  lcd.fill(LCD::RED)
  lcd.text(4, 4, "Auth failed", bg: LCD::RED, scale: 1)
  return
rescue WiFi::ConnectTimeout
  lcd.fill(LCD::RED)
  lcd.text(4, 4, "Timed out", bg: LCD::RED, scale: 1)
  return
end

lcd.fill(LCD::BLACK)
lcd.text(4, 4, "NTP syncing...", scale: 1)

t = Time.new(offset: 9)
t.sync(NTP_SERVER, interval: 5, timeout: 60)

lcd.fill(LCD::BLACK)
lcd.text(4, 4, "M5StickC PLUS", color: LCD::YELLOW, scale: 1)
lcd.text(4, 220, "by prremote", color: LCD::WHITE, scale: 1)

last_sync = t.epoch
loop do
  lcd.text(3, 90, t.to_s[0, 10], color: LCD::CYAN, scale: 1)   # YYYY-MM-DD
  lcd.text(3, 120, t.to_s[11, 8], color: LCD::WHITE, scale: 2) # HH:MM:SS
  t.sleep(1)
  if t - last_sync >= SYNC_INTERVAL
    last_sync = t.epoch
    t.sync(NTP_SERVER, interval: 5, timeout: 60)
  end
end
