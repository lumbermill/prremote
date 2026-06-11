# Device: Pico W only (requires CYW43 WiFi chip)
# Displays current time (JST = UTC+9) updated every second.
# Syncs once per hour via SNTP (UDP port 123, RFC 4330).
#
# Set SSID and PASSWORD before deploying.

SSID     = "360-raspi"
PASSWORD = "raspberry"

SYNC_INTERVAL = 3600 # seconds between re-syncs
NTP_SERVER = "ntp.nict.jp"

CYW43.init("JP")
puts "Connecting to #{SSID}..."
begin
  CYW43::WiFi.connect(SSID, PASSWORD, CYW43::Auth::WPA2_MIXED_PSK, 15)
  puts "Connected! IP: #{CYW43::WiFi.ipv4_address}"
rescue CYW43::WiFi::ConnectError => e
  puts "Auth failed: #{e.message}"
  return
rescue CYW43::WiFi::ConnectTimeout => e
  puts "Timed out: #{e.message}"
  return
end

t = Time.new(offset: 9)
puts "Syncing to #{NTP_SERVER}..."
t.sync(NTP_SERVER, interval: 5, timeout: 60) # retry every 5s until success
puts "Synced: #{t}"

last_sync = t.epoch
loop do
  puts t
  t.sleep(1)
  if t - last_sync >= SYNC_INTERVAL
    last_sync = t.epoch # reset timer regardless of outcome to avoid retry storm
    puts "Re-synced." if t.sync(NTP_SERVER, interval: 5, timeout: 60)
  end
end
