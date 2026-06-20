# Device: ESP32 (M5GO / M5Stack Core gen1)
# Countdown display for RubyKaigi 2027 (2027-04-13, JST).
# Shows days relative to the event: negative = days before, 0 = event day, positive = days after.
#
# Wiring: none — WiFi and LCD are built-in on M5GO.
#   LCD: ILI9342C SPI panel (320x240), CS=14, DC=27, RST=33, CLK=18, MOSI=23, BL=32
# Set SSID and PASSWORD before deploying.

SSID     = "MySSID"
PASSWORD = "MyPassword"

NTP_SERVER    = "ntp.nict.jp"
SYNC_INTERVAL = 3600

JST_OFFSET = 9 * 3600
# 2027-04-13 00:00:00 JST = epoch 1807542000
# JST day number = (1807542000 + 32400) / 86400 = 20921
EVENT_DAY = 20921

# RGB565 medium gray (128, 128, 128)
GRAY = 0x8410

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

# Ruby gem logo — top-left
gx, gy = 4, 4
r = LCD::RED
lcd.fill_rect(gx + 12, gy, 36, 5, r) # flat top crown
lcd.fill_rect(gx +  7, gy + 5, 46, 5, r) # upper shoulder
lcd.fill_rect(gx +  3, gy + 10, 54, 5, r)  # upper body
lcd.fill_rect(gx,      gy + 15, 60, 10, r) # widest band
lcd.fill_rect(gx + 6, gy + 25, 48, 7, r) # lower body 1
lcd.fill_rect(gx + 14, gy + 32, 32, 7, r)  # lower body 2
lcd.fill_rect(gx + 21, gy + 39, 18, 6, r)  # taper 1
lcd.fill_rect(gx + 26, gy + 45,  8, 4, r)  # taper 2
lcd.fill_rect(gx + 29, gy + 49,  2, 3, r)  # tip
lcd.fill_rect(gx +  9, gy + 6, 10, 3, LCD::WHITE) # glint highlight

# "RubyKaigi" scale 3 (24px/char → 216×24px), right edge at x=296
lcd.text(80, 10, "RubyKaigi", color: LCD::RED, scale: 3)
# "2027" scale 4 (32px/char → 128×32px), right-aligned under "RubyKaigi" (296-128=168)
lcd.text(168, 38, "2027", color: LCD::RED, scale: 4)

last_sync = t.epoch
last_day  = nil
loop do
  # Footer: "by prremote yyyy/mm/dd hh:mm:ss" in gray at screen bottom
  mm = t.month < 10 ? "0#{t.month}" : t.month.to_s
  dd = t.day   < 10 ? "0#{t.day}"   : t.day.to_s
  hh = t.hour  < 10 ? "0#{t.hour}"  : t.hour.to_s
  mi = t.min   < 10 ? "0#{t.min}"   : t.min.to_s
  ss = t.sec   < 10 ? "0#{t.sec}"   : t.sec.to_s
  # 31 chars * 8px = 248px; center: (320-248)/2 = 36
  lcd.text(36, 232, "by prremote #{t.year}/#{mm}/#{dd} #{hh}:#{mi}:#{ss}", color: GRAY, scale: 1)

  # Day counter — redraw only when JST date changes
  jst_day = (t.epoch + JST_OFFSET) / 86400
  if last_day != jst_day
    last_day = jst_day
    days = jst_day - EVENT_DAY
    day_str = days.to_s
    color = if days < 0
              LCD::CYAN
            elsif days == 0
              LCD::GREEN
            else
              LCD::YELLOW
            end
    # scale 6 = 48px/char; center horizontally, vertically in y=70..232
    x = (320 - (day_str.length * 48)) / 2
    lcd.fill_rect(0, 70, 320, 162, LCD::BLACK)
    lcd.text(x, 127, day_str, color: color, scale: 6)
  end

  t.sleep(1)
  if t.epoch - last_sync >= SYNC_INTERVAL
    last_sync = t.epoch
    t.sync(NTP_SERVER, interval: 5, timeout: 60)
  end
end
