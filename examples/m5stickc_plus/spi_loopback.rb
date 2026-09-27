# Device: M5StickC PLUS (ESP32-PICO-D4) — SPI loopback self-test.
# Wire MOSI -> MISO directly so the bus echoes whatever it sends:
#   Grove G32 (MOSI) <-> G33 (MISO) — short the Grove cable's yellow/white wires
# SCK is put on header G26 and can stay unconnected.
#
# The SPI defaults (SCK=18 / MOSI=23) are the M5GO's VSPI pins, which on this
# board drive the LCD's RST and DC lines — always pass pins explicitly here.
# unit: 0 (SPI2) is separate from the LCD's SPI3, so both can be used at once.

spi = SPI.new(unit: 0, sck_pin: 26, copi_pin: 32, cipo_pin: 33)

sent = [0x01, 0x02, 0x03, 0xA5, 0xFF]
got  = spi.transfer(sent)

echoed = got.bytes
puts "sent:    #{sent.inspect}"
puts "echoed:  #{echoed.inspect}"

if echoed == sent
  puts "OK: loopback matched"
else
  puts "MISMATCH: check the G32(MOSI)<->G33(MISO) jumper"
end
