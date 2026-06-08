# Device: Pico / Pico W — MAX7219 8x8 LED matrix module
# Wiring: DIN → GPIO 19 (COPI)
#         CLK → GPIO 18 (SCK)
#         CS  → GPIO 17
#         VCC → 5V (VBUS),  GND → GND
#         CIPO (GPIO 16) not connected — MAX7219 is write-only
# Note: MAX7219 requires VCC >= 4V; many modules work at 3.3V in practice.

spi = SPI.new(unit: :RP2040_SPI0,
              sck_pin: 18, copi_pin: 19, cipo_pin: 16, cs_pin: 17,
              frequency: 1_000_000)

# MAX7219 register addresses
REG_DECODE    = 0x09
REG_INTENSITY = 0x0A
REG_SCANLIMIT = 0x0B
REG_SHUTDOWN  = 0x0C
REG_DISPTEST  = 0x0F

def reg_write(spi, reg, val)
  spi.select
  spi.transfer([reg, val])
  spi.deselect
end

# Rows 0..7 map to registers 0x01..0x08; bit7 = leftmost column.
def show(spi, rows)
  i = 0
  while i < 8
    reg_write(spi, i + 1, rows[i])
    i += 1
  end
end

# Initialize MAX7219
reg_write(spi, REG_DISPTEST,  0x00)  # normal mode (disable display test)
reg_write(spi, REG_SCANLIMIT, 0x07)  # scan all 8 rows
reg_write(spi, REG_DECODE,    0x00)  # raw bit pattern, no BCD decode
reg_write(spi, REG_INTENSITY, 0x04)  # brightness: 0=min, 15=max
reg_write(spi, REG_SHUTDOWN,  0x01)  # exit shutdown → LEDs on

SMILEY = [
  0b00111100,
  0b01000010,
  0b10100101,
  0b10000001,
  0b10100101,
  0b10011001,
  0b01000010,
  0b00111100,
]

HEART = [
  0b00000000,
  0b01100110,
  0b11111111,
  0b11111111,
  0b01111110,
  0b00111100,
  0b00011000,
  0b00000000,
]

loop do
  show(spi, SMILEY)
  sleep 1
  show(spi, HEART)
  sleep 1
end
