# Device: Seeed Studio XIAO ESP32C6 + ILI9341 2.8" SPI TFT (MSP2807, 320x240)
#
# Goal: just get something on the screen — a solid color, a couple of rects,
# and some text. Touch (XPT2046) and the SD slot are not used here.
#
# Wiring (MSP2807 module <- XIAO ESP32C6):
#   VCC        <- 3V3
#   GND        <- GND
#   CS         <- D3  / GPIO21
#   RESET      <- D0  / GPIO0
#   DC (RS)    <- D1  / GPIO1
#   SDI (MOSI) <- D10 / GPIO18
#   SCK        <- D8  / GPIO19
#   LED (BL)   <- D6  / GPIO16   (or tie to 3V3 for always-on; then use bl_pin: -1)
#   SDO (MISO) <- not connected  (display-only, never read back)
#   T_* / SD_* (touch / SD card) <- not connected
#
# Notes:
#   * MSP2807 is a standard ILI9341, so invert: false (M5Stack ILI9342C uses true).
#   * If colors look like a photo negative, flip `invert:`.
#   * madctl: 0xE8 gives an upright, non-mirrored 320x240 landscape on this
#     ILI9341 (verified on hardware). The driver's per-rotation MADCTL table is
#     tuned for the M5Stack ILI9342C (native landscape); the ILI9341 is natively
#     portrait (240x320) and needs the MV bit set, hence the explicit override.
#     For an upside-down (180°) landscape use madctl: 0x28.
#   * If red shows up as blue, the panel is RGB not BGR — clear MADCTL bit 0x08
#     (e.g. madctl: 0xE0).
#   * D8/D9/D10 are confirmed on the XIAO silk; CS/DC/RST/BL pins above are the
#     expected D3/D0/D1/D6 mapping — verify against your board if nothing shows.

lcd = LCD.new(invert: false, rotation: 0, madctl: 0xE8,
              sck_pin: 19, mosi_pin: 18, miso_pin: -1,
              cs_pin: 21, dc_pin: 1, rst_pin: 0, bl_pin: 16)

# 1) Liveness check: paint the whole screen red. The rect is intentionally
#    oversized so it covers the panel regardless of rotation (it gets clipped).
lcd.fill_rect(0, 0, 320, 320, LCD::RED)
sleep 1

# 2) Clear to black, then a couple of filled rectangles.
lcd.fill_rect(0, 0, 320, 320, LCD::BLACK)
lcd.fill_rect(20, 20, 120, 80, LCD::BLUE)
lcd.fill_rect(160, 120, 120, 80, LCD::GREEN)

# 3) Text (built-in 8x8 font, scaled up).
lcd.text(16, 16, "Hello from", color: LCD::WHITE, scale: 3)
lcd.text(16, 56, "XIAO C6!", color: LCD::YELLOW, scale: 3)

puts "LCD demo done"
