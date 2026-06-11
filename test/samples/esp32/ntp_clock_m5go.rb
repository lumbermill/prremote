# Device: ESP32 (M5GO / M5Stack Core gen1)
# Displays current time (JST = UTC+9) on the M5GO LCD, updated every second.
# Syncs once per hour via SNTP.
#
# Wiring: none — WiFi and LCD are built-in on M5GO.
#   LCD: ILI9342C SPI panel (320x240), CS=14, DC=27, RST=33, CLK=18, MOSI=23, BL=32
# Set SSID and PASSWORD before deploying.

SSID     = "MySSID"
PASSWORD = "MyPassword"

SYNC_INTERVAL = 3600
NTP_SERVER    = "ntp.nict.jp"

lcd = LCD.new
lcd.fill(LCD::BLACK)
lcd.text("Connecting...", 4, 4, LCD::WHITE, scale: 2)

CYW43.init
begin
  CYW43::WiFi.connect(SSID, PASSWORD, CYW43::Auth::WPA2_AES_PSK, 20)
rescue CYW43::WiFi::ConnectError => e
  lcd.fill(LCD::RED)
  lcd.text("Auth failed", 4, 4, LCD::WHITE, scale: 2)
  return
rescue CYW43::WiFi::ConnectTimeout => e
  lcd.fill(LCD::RED)
  lcd.text("Timed out", 4, 4, LCD::WHITE, scale: 2)
  return
end

lcd.fill(LCD::BLACK)
lcd.text("NTP syncing...", 4, 4, LCD::WHITE, scale: 2)

t = Time.new(offset: 9)
t.sync(NTP_SERVER, interval: 5, timeout: 60)

last_sync = t.epoch
loop do
  lcd.fill(LCD::BLACK)
  lcd.text(t.to_s[0, 10], 4,  60, LCD::CYAN,   scale: 3)  # YYYY-MM-DD
  lcd.text(t.to_s[11, 8], 20, 110, LCD::WHITE,  scale: 4)  # HH:MM:SS
  lcd.text("JST (UTC+9)",  4, 200, LCD::YELLOW, scale: 2)
  t.sleep(1)
  if t - last_sync >= SYNC_INTERVAL
    last_sync = t.epoch
    t.sync(NTP_SERVER, interval: 5, timeout: 60)
  end
end
