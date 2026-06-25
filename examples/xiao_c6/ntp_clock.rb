# Device: Seeed Studio XIAO ESP32C6
# Connects to WiFi, syncs time via NTP, then prints JST (UTC+9) every second.
# No LCD on XIAO — output goes to serial via prremote.
# Wiring: none — WiFi is built-in.
# Set SSID and PASSWORD before deploying.

SSID     = "MySSID"
PASSWORD = "MyPassword"

NTP_SERVER    = "ntp.nict.jp"
SYNC_INTERVAL = 3600

CYW43.init
puts "Connecting to #{SSID}..."
begin
  CYW43::WiFi.connect(SSID, PASSWORD, CYW43::Auth::WPA2_MIXED_PSK, 20)
  puts "Connected: #{CYW43::WiFi.ipv4_address}"
rescue CYW43::WiFi::ConnectError => e
  puts "Auth failed: #{e.message}"
  return
rescue CYW43::WiFi::ConnectTimeout => e
  puts "Timed out: #{e.message}"
  return
end

t = Time.new(offset: 9)
puts "Syncing NTP..."
t.sync(NTP_SERVER, interval: 5, timeout: 60)
puts "Ready."

last_sync = t.epoch
loop do
  puts t.to_s
  t.sleep(1)
  if t - last_sync >= SYNC_INTERVAL
    last_sync = t.epoch
    t.sync(NTP_SERVER, interval: 5, timeout: 60)
  end
end
