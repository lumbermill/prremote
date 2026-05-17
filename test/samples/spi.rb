# Device: Pico / Pico W — MCP3208 8-channel 12-bit SPI ADC
# Wiring: SCK → GPIO 18, COPI → GPIO 19, CIPO → GPIO 16, CS → GPIO 17
#         VDD/VREF → 3.3V, AGND/DGND → GND

spi = SPI.new(unit: :RP2040_SPI0,
              sck_pin: 18, copi_pin: 19, cipo_pin: 16, cs_pin: 17,
              frequency: 1_000_000)

# Read a single-ended channel (0..7).
# Protocol: 3-byte transfer — [start|SGL|D2, D1D0|padding, don't-care]
def mcp3208_read(spi, channel)
  byte1 = 0b110 | ((channel >> 2) & 1) # start=1, SGL=1, D2
  byte2 = (channel & 0b11) << 6 # D1, D0
  spi.select
  result = spi.transfer([byte1, byte2, 0x00])
  spi.deselect
  ((result[1] & 0x0F) << 8) | result[2]
end

loop do
  value   = mcp3208_read(spi, 0) # CH0
  voltage = value * 3.3 / 4095.0
  puts "CH0: #{value} (#{voltage} V)"
  sleep 1
end
