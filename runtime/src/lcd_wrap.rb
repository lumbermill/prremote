# LCD wrapper for ILI9342C / ILI9341 / ST7789-class SPI panels (ESP32 builds
# only).
#
# The C primitives (_lcd_init, _lcd_fill_rect, _lcd_text, _lcd_brightness,
# _lcd_draw_line, _lcd_draw_circle, _lcd_draw_ellipse)
# live in esp32/main/lcd_ili9342c.c. Pin defaults match the M5GO /
# M5Stack Core gen1; pass other pins for different ILI9342C/ILI9341/ST7789
# boards.
#
# Colors are RGB565 integers — use the constants or LCD.rgb(r, g, b).
# `invert:` toggles INVON/INVOFF: M5Stack ILI9342C and ST7789 (M5StickC/PLUS)
# panels need true (default); standard ILI9341 panels (e.g. MSP2807) need
# false.
# `madctl:` overrides the per-rotation MADCTL byte (memory access control:
# MY=0x80, MX=0x40, MV=0x20, BGR=0x08). The default table is tuned for the
# ILI9342C (native landscape); portrait-native panels need MV set for
# landscape — e.g. madctl: 0x28 at rotation 0. Leave nil to use the table.
# `width:`/`height:` are the panel's own resolution at rotation 0 (odd
# rotations swap them). `offset_x:`/`offset_y:` shift the CASET/RASET window
# into the controller's RAM — needed when the visible area is smaller than
# the RAM window, e.g. the M5StickC/PLUS's 135x240 ST7789v2 sits inside a
# 240x320 window at offset (52, 40).
# Note: the panel shares an SPI host with the SPI class — SPI.new(unit: 1) on
# ESP32 classic, SPI.new(unit: 0) on ESP32-C6; use the other unit for external
# SPI devices while the LCD is active.
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

  attr_reader :width, :height

  # 8-bit r/g/b → RGB565
  def self.rgb(r, g, b)
    ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
  end

  def initialize(rotation: 0, sck_pin: 18, mosi_pin: 23, miso_pin: 19,
                 cs_pin: 14, dc_pin: 27, rst_pin: 33, bl_pin: 32,
                 invert: true, madctl: nil,
                 width: WIDTH, height: HEIGHT, offset_x: 0, offset_y: 0)
    ok = _lcd_init(rotation, sck_pin, mosi_pin, miso_pin,
                   cs_pin, dc_pin, rst_pin, bl_pin, invert ? 1 : 0,
                   madctl || -1, width, height, offset_x, offset_y)
    raise "LCD init failed" unless ok

    swap    = (rotation & 1) != 0
    @width  = swap ? height : width
    @height = swap ? width : height
  end

  def fill(color)
    _lcd_fill_rect(0, 0, @width, @height, color)
  end

  def fill_rect(x, y, w, h, color)
    _lcd_fill_rect(x, y, w, h, color)
  end

  def pixel(x, y, color)
    _lcd_fill_rect(x, y, 1, 1, color)
  end

  def draw_line(x0, y0, x1, y1, color)
    _lcd_draw_line(x0, y0, x1, y1, color)
  end

  def draw_circle(cx, cy, r, color, fill: false)
    _lcd_draw_circle(cx, cy, r, color, fill ? 1 : 0)
  end

  def draw_ellipse(cx, cy, a, b, color, fill: false)
    _lcd_draw_ellipse(cx, cy, a, b, color, fill ? 1 : 0)
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
