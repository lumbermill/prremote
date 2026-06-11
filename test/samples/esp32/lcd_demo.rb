# Device: M5GO / M5Stack Core (ESP32)
# LCD demo: color swatches + a live counter — no wiring needed.
# Deployable: `prremote deploy test/samples/esp32/lcd_demo.rb` makes it run
# standalone on power-up; Ctrl+C (prremote reset) returns to READY.
lcd = LCD.new
lcd.fill(LCD::BLACK)

lcd.text(16, 12, "prremote demo", color: LCD::WHITE, scale: 3)

# Color swatch row
colors = [LCD::RED, LCD::ORANGE, LCD::YELLOW, LCD::GREEN,
          LCD::CYAN, LCD::BLUE, LCD::MAGENTA, LCD::WHITE]
colors.each_with_index do |c, i|
  lcd.fill_rect(16 + (i * 36), 56, 32, 32, c)
end

lcd.text(16, 110, "uptime", color: LCD::CYAN, scale: 2)

count = 0
loop do
  lcd.text(16, 140, "#{count} s   ", color: LCD::YELLOW, scale: 4)
  count += 1
  sleep 1
end
