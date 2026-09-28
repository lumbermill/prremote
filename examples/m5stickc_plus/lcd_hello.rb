# Device: M5StickC PLUS (ESP32-PICO-D4)
# LCD hello world — no wiring needed (internal ST7789v2 panel, 135x240).
#
# M5StickCPlus is a board library the prremote CLI compiles in automatically
# when a script mentions it (runtime installed with `install -b m5stickc_plus`,
# or the plain esp32 one). M5StickCPlus.new powers the panel through the
# AXP192 PMIC, and #lcd returns a plain LCD with this panel's pins, size,
# RAM offset and RGB color order preset for each rotation — see
# lib/prremote/boards/m5stickc_plus.rb in the gem for the raw LCD.new call.
stick = M5StickCPlus.new
lcd = stick.lcd # rotation: 0 = portrait, USB at the bottom
lcd.fill(LCD::BLACK)
lcd.text(4, 40, "Hello", color: LCD::WHITE, scale: 2)
lcd.text(4, 70, "from Ruby!", color: LCD::WHITE, scale: 1)
lcd.text(4, 100, "M5StickC PLUS", color: LCD::CYAN, scale: 1)
lcd.fill_rect(4, 130, 120, 4, LCD::ORANGE)
puts "drawn #{lcd.width}x#{lcd.height}"
