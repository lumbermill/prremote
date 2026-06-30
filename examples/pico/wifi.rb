# Device: Pico W only (requires onboard WiFi; Pico / Pico 2 have no radio)
SSID     = "MySSID"
PASSWORD = "MyPassword"

WiFi.init("JP")
puts "Connecting to #{SSID}..."

begin
  WiFi.connect(SSID, PASSWORD, WiFi::Auth::WPA2_MIXED_PSK, 15)
  puts "Connected!"
  puts "IP:      #{WiFi.ipv4_address}"
  puts "Netmask: #{WiFi.ipv4_netmask}"
  puts "Gateway: #{WiFi.ipv4_gateway}"
rescue WiFi::ConnectError => e
  puts "Auth failed: #{e.message}"
rescue WiFi::ConnectTimeout => e
  puts "Timed out: #{e.message}"
end
