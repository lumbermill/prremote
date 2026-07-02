# Device: M5GO / M5Stack Core (ESP32)
# LCD shape primitives — no wiring needed (internal ILI9342C panel, 320x240).
# Exercises LCD#draw_line / #draw_circle / #draw_ellipse (outline + fill:
# true). All three are implemented in C (lcd_ili9342c.c) rather than as
# fill_rect/pixel loops in Ruby, so they stay fast even at large radii.
lcd = LCD.new
lcd.fill(LCD::BLACK)

lcd.text(8, 4, "LCD shapes", color: LCD::WHITE, scale: 2)

# Lines: horizontal, vertical, and diagonal all go through the same call.
lcd.draw_line(8, 40, 150, 40, LCD::RED)
lcd.draw_line(8, 40, 8, 90, LCD::RED)
lcd.draw_line(8, 90, 150, 40, LCD::RED)

# Circle: outline then filled.
lcd.draw_circle(210, 65, 25, LCD::CYAN)
lcd.draw_circle(280, 65, 25, LCD::CYAN, fill: true)

# Ellipse: outline then filled, wider than tall.
lcd.draw_ellipse(80, 160, 60, 30, LCD::YELLOW)
lcd.draw_ellipse(230, 160, 40, 60, LCD::MAGENTA, fill: true)

puts "drawn"
