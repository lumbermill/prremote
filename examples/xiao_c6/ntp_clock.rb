# Device: Seeed Studio XIAO ESP32C6
# Connects to WiFi, syncs time via NTP, then prints JST (UTC+9) every second.
# No LCD on XIAO — output goes to serial via prremote.
# Wiring: none — WiFi is built-in.
# Set SSID and PASSWORD before deploying.

SSID     = "MySSID"
PASSWORD = "MyPassword"

NTP_SERVER    = "ntp.nict.jp"
SYNC_INTERVAL = 3600

WiFi.init
puts "Connecting to #{SSID}..."
begin
  WiFi.connect(SSID, PASSWORD, WiFi::Auth::WPA2_MIXED_PSK, 20)
  puts "Connected: #{WiFi.ipv4_address}"
rescue WiFi::ConnectError => e
  puts "Auth failed: #{e.message}"
  return
rescue WiFi::ConnectTimeout => e
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
