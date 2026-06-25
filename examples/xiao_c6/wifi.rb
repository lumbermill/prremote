# Device: Seeed Studio XIAO ESP32C6
# Connects to WiFi (802.11ax / Wi-Fi 6) and prints network info.
# Wiring: none — WiFi is built-in.
# Set SSID and PASSWORD before deploying.

SSID     = "MySSID"
PASSWORD = "MyPassword"

CYW43.init
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
