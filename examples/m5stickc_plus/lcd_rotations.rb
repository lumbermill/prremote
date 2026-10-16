# Device: M5StickC PLUS (ESP32-PICO-D4)
# Cycles the LCD through all four rotations, drawing a 1-px white border
# around the visible area and the rotation number. Use it to check that
# every rotation fills the panel exactly: all four border lines visible and
# no stray noise line along any edge (a wrong RAM offset leaves one row or
# column undrawn). No wiring needed.
#
# stick.lcd(rotation:) presets the offset per rotation (see lcd_hello.rb).
# Takes 40 s: 4 rotations x 5 s, twice.

stick = M5StickCPlus.new

def draw(lcd, r)
  w = lcd.width
  h = lcd.height
  lcd.fill(LCD::BLACK)
  lcd.fill_rect(0, 0, w, 1, LCD::WHITE)
  lcd.fill_rect(0, h - 1, w, 1, LCD::WHITE)
  lcd.fill_rect(0, 0, 1, h, LCD::WHITE)
  lcd.fill_rect(w - 1, 0, 1, h, LCD::WHITE)
  lcd.text(10, 10, "rot #{r}", color: LCD::YELLOW, scale: 2)
  lcd.text(10, 40, "#{w}x#{h}", color: LCD::CYAN, scale: 1)
end

2.times do
  4.times do |r|
    lcd = stick.lcd(rotation: r)
    draw(lcd, r)
    puts "rotation #{r}: #{lcd.width}x#{lcd.height}"
    sleep 5
  end
end
puts "done"
