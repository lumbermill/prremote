# Device: M5GO / M5Stack Core (ESP32)
# LCD hello world — no wiring needed (internal ILI9342C panel, 320x240).
# Pin defaults in LCD.new match the M5Stack Core gen1; for other ILI9342C
# boards pass sck_pin: / mosi_pin: / cs_pin: / dc_pin: / rst_pin: / bl_pin:.
lcd = LCD.new
lcd.fill(LCD::BLACK)
lcd.text(16, 60, "Hello from Ruby!", color: LCD::WHITE, scale: 2)
lcd.text(16, 100, "prremote on ESP32", color: LCD::CYAN, scale: 2)
lcd.fill_rect(16, 140, 288, 4, LCD::ORANGE)
puts "drawn"
