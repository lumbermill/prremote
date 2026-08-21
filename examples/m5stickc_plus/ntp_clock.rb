# Device: M5StickC PLUS (ESP32-PICO-D4)
# Displays current time (JST = UTC+9) on the built-in LCD, updated every
# second. Syncs once per hour via SNTP.
#
# Wiring: none — WiFi and LCD are built-in. Like lcd_hello.rb, the AXP192
# PMIC (I2C 0x34) needs LDO2/LDO3 enabled before the panel shows anything.
# Set SSID and PASSWORD before deploying.

SSID     = "MySSID"
PASSWORD = "MyPassword"

SYNC_INTERVAL = 3600
NTP_SERVER    = "ntp.nict.jp"

i2c = I2C.new(sda_pin: 21, scl_pin: 22)
i2c.write(0x34, 0x28, 0xCC)                 # LDO2/LDO3 voltage = 3.0V
cur = i2c.read(0x34, 1, 0x12).getbyte(0)
i2c.write(0x34, 0x12, cur | 0x4D)           # enable Ext, LDO2, LDO3, DCDC1

# madctl: 0x00 — see lcd_hello.rb; this ST7789 wants plain RGB, not the
# BGR the default table assumes for the ILI9342C (M5GO).
lcd = LCD.new(sck_pin: 13, mosi_pin: 15, miso_pin: -1, cs_pin: 5, dc_pin: 23,
              rst_pin: 18, bl_pin: -1, invert: true, madctl: 0x00,
              width: 135, height: 240, offset_x: 52, offset_y: 40)
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
