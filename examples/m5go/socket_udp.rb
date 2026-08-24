# Device: ESP32 (M5Stack / M5GO or any classic ESP32 board)
# UDPSocket sample — connects to WiFi, then sends comma-separated numeric
# datagrams to a UDP server and prints each reply. Exercises the esp32 socket
# layer end to end: UDPSocket.new, connect (getaddrinfo / .local mDNS
# resolution), send, and recvfrom_nonblock. TCPSocket is available too and
# works the same as on picow / esp32c6.
#
# Wiring: none — WiFi is built-in. Set WIFI_SSID / WIFI_PASS / HOST first.
#
# Because the socket is connect()'d, it only accepts datagrams from HOST:PORT —
# the server must reply *from the same port it received on*, to the sender's
# address. Minimal CRuby echo server to test against:
#
#     require "socket"
#     s = UDPSocket.new
#     s.bind("0.0.0.0", 2000)
#     loop do
#       msg, addr = s.recvfrom(64)
#       s.send(msg, 0, addr[3], addr[1])   # reply FROM :2000 TO the sender
#     end

WIFI_SSID = "MySSID"
WIFI_PASS = "MyPassword"
HOST      = "raspi.local" # a .local mDNS name or a plain IP (e.g. "10.42.0.1")
PORT      = 2000

WiFi.init
puts "Connecting to #{WIFI_SSID}..."

begin
  WiFi.connect(WIFI_SSID, WIFI_PASS, WiFi::Auth::WPA2_MIXED_PSK, 15)
  puts "Connected! IP: #{WiFi.ipv4_address}"

  sock = UDPSocket.new
  puts "Resolving + connecting UDP to #{HOST}:#{PORT}..."
  sock.connect(HOST, PORT) # getaddrinfo here (handles .local via mDNS)
  puts "UDP connected."

  5.times do |_i|
    msg = "100,200"
    sent = sock.send(msg, 0)
    puts "-> sent #{sent} bytes: #{msg}"

    # Poll up to ~1 s for a reply (the socket is non-blocking).
    reply = nil
    200.times do
      result = sock.recvfrom_nonblock(64)
      if result
        data, addr = result
        reply = data
        puts "<- recv: #{data.inspect} from #{addr[2]}:#{addr[1]}"
        break
      end
      sleep(0.005)
    end
    puts "   (no reply within ~1s)" unless reply

    sleep(0.5)
  end

  sock.close
  puts "done."
rescue WiFi::ConnectError => e
  puts "Auth failed: #{e.message}"
rescue WiFi::ConnectTimeout => e
  puts "Timed out: #{e.message}"
rescue SocketError => e
  puts "Socket error: #{e.message}" # e.g. mDNS/DNS resolution failed
rescue StandardError => e
  puts "Error: #{e.class} #{e.message}"
ensure
  sock.close if sock && !sock.closed?
end
