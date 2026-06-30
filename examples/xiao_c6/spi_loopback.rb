# Device: Seeed Studio XIAO ESP32C6 — SPI loopback self-test (no extra device).
# Wire MOSI -> MISO directly so the bus echoes whatever it sends:
#   D10 (MOSI, GPIO18) <-> D9 (MISO, GPIO20)
# SCK (D8, GPIO19) can stay unconnected. ESP32-C6 default SPI host is SPI2.
#
# full-duplex transfer() shifts bytes out on MOSI; with the jumper in place the
# same bytes appear on MISO and come back as the return String. SPI is also
# exercised by lcd_hello.rb (the LCD is an MOSI-only device); this test adds the
# read path with no hardware beyond a single jumper wire.

spi = SPI.new(sck_pin: 19, copi_pin: 18, cipo_pin: 20)

sent = [0x01, 0x02, 0x03, 0xA5, 0xFF]
got  = spi.transfer(sent)

# transfer() returns a String of the received bytes.
echoed = got.bytes
puts "sent:    #{sent.inspect}"
puts "echoed:  #{echoed.inspect}"

if echoed == sent
  puts "OK: loopback matched"
else
  puts "MISMATCH: check the D10(MOSI)<->D9(MISO) jumper"
end
