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
lcd.text(4, 4, "Connecting...", scale: 2)

CYW43.init
begin
  CYW43::WiFi.connect(SSID, PASSWORD, CYW43::Auth::WPA2_MIXED_PSK, 20)
rescue CYW43::WiFi::ConnectError
  lcd.fill(LCD::RED)
  lcd.text(4, 4, "Auth failed", bg: LCD::RED, scale: 2)
  return
rescue CYW43::WiFi::ConnectTimeout
  lcd.fill(LCD::RED)
  lcd.text(4, 4, "Timed out", bg: LCD::RED, scale: 2)
  return
end

lcd.fill(LCD::BLACK)
lcd.text(4, 4, "NTP syncing...", scale: 2)

t = Time.new(offset: 9)
t.sync(NTP_SERVER, interval: 5, timeout: 60)

lcd.fill(LCD::BLACK)
lcd.text(10, 185, "JST (UTC+9)", color: LCD::YELLOW, scale: 2)
lcd.text(10, 207, "by prremote", color: LCD::WHITE,  scale: 2)

# Ruby gem logo (Ruby language) — bottom-right corner.
# Flat-top faceted diamond: narrow crown widens to peak, then tapers to a point.
gx, gy = 256, 182
r = LCD::RED
lcd.fill_rect(gx + 12, gy,      36, 5,  r)  # flat top crown
lcd.fill_rect(gx +  7, gy +  5, 46, 5,  r)  # upper shoulder
lcd.fill_rect(gx +  3, gy + 10, 54, 5,  r)  # upper body
lcd.fill_rect(gx,      gy + 15, 60, 10, r)  # widest band
lcd.fill_rect(gx +  6, gy + 25, 48, 7,  r)  # lower body 1
lcd.fill_rect(gx + 14, gy + 32, 32, 7,  r)  # lower body 2
lcd.fill_rect(gx + 21, gy + 39, 18, 6,  r)  # taper 1
lcd.fill_rect(gx + 26, gy + 45,  8, 4,  r)  # taper 2
lcd.fill_rect(gx + 29, gy + 49,  2, 3,  r)  # tip
lcd.fill_rect(gx +  9, gy +  6, 10, 3,  LCD::WHITE)  # glint highlight

last_sync = t.epoch
loop do
  lcd.text(40, 60, t.to_s[0, 10], color: LCD::CYAN, scale: 3)  # YYYY-MM-DD centered
  lcd.text(32, 110, t.to_s[11, 8], color: LCD::WHITE, scale: 4) # HH:MM:SS centered
  t.sleep(1)
  if t - last_sync >= SYNC_INTERVAL
    last_sync = t.epoch
    t.sync(NTP_SERVER, interval: 5, timeout: 60)
  end
end
