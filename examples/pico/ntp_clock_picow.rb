# Device: Pico W only (requires onboard WiFi; Pico / Pico 2 have no radio)
# Displays current time (JST = UTC+9) updated every second.
# Syncs once per hour via SNTP (UDP port 123, RFC 4330).
#
# Set SSID and PASSWORD before deploying.

SSID     = "MySSID"
PASSWORD = "MyPassword"

SYNC_INTERVAL = 3600 # seconds between re-syncs
NTP_SERVER = "ntp.nict.jp"

WiFi.init("JP")
puts "Connecting to #{SSID}..."
begin
  WiFi.connect(SSID, PASSWORD, WiFi::Auth::WPA2_MIXED_PSK, 15)
  puts "Connected! IP: #{WiFi.ipv4_address}"
rescue WiFi::ConnectError => e
  puts "Auth failed: #{e.message}"
  return
rescue WiFi::ConnectTimeout => e
  puts "Timed out: #{e.message}"
  return
end

t = Time.new(offset: 9)
puts "Syncing to #{NTP_SERVER}..."
t.sync(NTP_SERVER, interval: 5, timeout: 60) # retry every 5s until success
# mruby/c does not call a Ruby-defined #to_s in interpolation; call it explicitly.
puts "Synced: #{t.to_s}"

last_sync = t.epoch
loop do
  puts t.to_s
  t.sleep(1)
  if t - last_sync >= SYNC_INTERVAL
    last_sync = t.epoch # reset timer regardless of outcome to avoid retry storm
    puts "Re-synced." if t.sync(NTP_SERVER, interval: 5, timeout: 60)
  end
end
