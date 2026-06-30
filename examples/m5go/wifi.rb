# Device: ESP32 (M5Stack / M5GO or any ESP32 board)
# Connects to WiFi and prints IP address information.
#
# Wiring: none — WiFi is built-in.
# Set SSID and PASSWORD before deploying.

SSID     = "MySSID"
PASSWORD = "MyPassword"

WiFi.init
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
