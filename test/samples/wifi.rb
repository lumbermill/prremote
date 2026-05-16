# Device: Pico W only (requires CYW43 WiFi chip)
SSID     = "MySSID"
PASSWORD = "MyPassword"

CYW43.init
puts "Connecting to #{SSID}..."

status = CYW43::WiFi.connect(SSID, PASSWORD, timeout: 15_000)
if status == 0
  puts "Connected!"
  puts "IP:      #{CYW43::WiFi.ip_address}"
  puts "Netmask: #{CYW43::WiFi.netmask}"
  puts "Gateway: #{CYW43::WiFi.gateway}"
else
  puts "Connection failed (status=#{status})"
end
