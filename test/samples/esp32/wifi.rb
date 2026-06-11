# Device: ESP32 (M5Stack / M5GO or any ESP32 board)
# Connects to WiFi and prints IP address information.
#
# Wiring: none — WiFi is built-in.
# Set SSID and PASSWORD before deploying.

SSID     = "MySSID"
PASSWORD = "MyPassword"

CYW43.init
puts "Connecting to #{SSID}..."

begin
  CYW43::WiFi.connect(SSID, PASSWORD, CYW43::Auth::WPA2_AES_PSK, 15)
  puts "Connected!"
  puts "IP:      #{CYW43::WiFi.ipv4_address}"
  puts "Netmask: #{CYW43::WiFi.ipv4_netmask}"
  puts "Gateway: #{CYW43::WiFi.ipv4_gateway}"
rescue CYW43::WiFi::ConnectError => e
  puts "Auth failed: #{e.message}"
rescue CYW43::WiFi::ConnectTimeout => e
  puts "Timed out: #{e.message}"
end
