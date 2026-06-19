# Device: Pico W only (requires CYW43 WiFi chip)
SSID     = "MySSID"
PASSWORD = "MyPassword"

CYW43.init("JP")
puts "Connecting to #{SSID}..."

begin
  CYW43::WiFi.connect(SSID, PASSWORD, CYW43::Auth::WPA2_MIXED_PSK, 15)
  puts "Connected!"
  puts "IP:      #{CYW43::WiFi.ipv4_address}"
  puts "Netmask: #{CYW43::WiFi.ipv4_netmask}"
  puts "Gateway: #{CYW43::WiFi.ipv4_gateway}"
rescue CYW43::WiFi::ConnectError => e
  puts "Auth failed: #{e.message}"
rescue CYW43::WiFi::ConnectTimeout => e
  puts "Timed out: #{e.message}"
end
