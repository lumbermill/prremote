# Device: Pico W only (requires CYW43 WiFi chip)
SSID     = "MySSID"
PASSWORD = "MyPassword"
COUNTRY  = "JP"

CYW43.init(COUNTRY)
CYW43.enable_sta_mode
puts "Connecting to #{SSID}..."

begin
  CYW43.connect_timeout(SSID, PASSWORD, CYW43::Auth::WPA2_MIXED_PSK, 15)
  puts "Connected!"
  puts "IP:      #{CYW43.ipv4_address}"
  puts "Netmask: #{CYW43.ipv4_netmask}"
  puts "Gateway: #{CYW43.ipv4_gateway}"
rescue CYW43::ConnectTimeout => e
  puts "Connection failed: #{e.message}"
end
