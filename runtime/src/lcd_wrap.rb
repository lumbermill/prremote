# LCD wrapper for ILI9342C-class SPI panels (ESP32 builds only).
#
# The C primitives (_lcd_init, _lcd_fill_rect, _lcd_text, _lcd_brightness)
# live in esp32/main/lcd_ili9342c.c. Pin defaults match the M5GO /
# M5Stack Core gen1; pass other pins for different ILI9342C/ILI9341 boards.
#
# Colors are RGB565 integers — use the constants or LCD.rgb(r, g, b).
# Note: the panel claims SPI unit 1 (VSPI); use SPI.new(unit: 0) for
# external SPI devices while the LCD is active.
class LCD
  WIDTH  = 320
  HEIGHT = 240

  BLACK   = 0x0000
  WHITE   = 0xFFFF
  RED     = 0xF800
  GREEN   = 0x07E0
  BLUE    = 0x001F
  YELLOW  = 0xFFE0
  CYAN    = 0x07FF
  MAGENTA = 0xF81F
  ORANGE  = 0xFD20

  # 8-bit r/g/b → RGB565
  def self.rgb(r, g, b)
    ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
  end

  def initialize(rotation: 0, sck_pin: 18, mosi_pin: 23, miso_pin: 19,
                 cs_pin: 14, dc_pin: 27, rst_pin: 33, bl_pin: 32)
    ok = _lcd_init(rotation, sck_pin, mosi_pin, miso_pin,
                   cs_pin, dc_pin, rst_pin, bl_pin)
    raise "LCD init failed" unless ok
  end

  def fill(color)
    _lcd_fill_rect(0, 0, WIDTH, HEIGHT, color)
  end

  def fill_rect(x, y, w, h, color)
    _lcd_fill_rect(x, y, w, h, color)
  end

  def pixel(x, y, color)
    _lcd_fill_rect(x, y, 1, 1, color)
  end

  # Draws 8x8-font text scaled by `scale` (1-4). Each character cell is
  # 8*scale pixels; drawing stops at the right edge.
  def text(x, y, str, color: WHITE, bg: BLACK, scale: 2)
    _lcd_text(x, y, str, color, bg, scale)
  end

  # 0-100 (%). Only effective when the backlight pin supports PWM.
  def brightness=(pct)
    _lcd_brightness(pct)
  end
end
