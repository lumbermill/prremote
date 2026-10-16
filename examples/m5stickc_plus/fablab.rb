# Device: M5StickC PLUS (ESP32-PICO-D4)
# A joke sample: "Fablab" filling the screen, rotated 90° clockwise (hold
# the stick upright, text reads top-to-bottom). Press button A to blink the
# text to a new color; press button B to blink the background instead —
# handy as a visual "which button did I just press?" check.
#
# Wiring: none — everything built-in (M5StickCPlus: see lcd_hello.rb).

stick = M5StickCPlus.new
# rotation: 3 is "90° clockwise" on this panel (rotation: 1 is the other
# landscape, upside down from this one). Landscape swaps LCD#width/#height
# to 240x135.
lcd = stick.lcd(rotation: 3)
btn_a = stick.button_a
btn_b = stick.button_b

FG_COLORS = [LCD::CYAN, LCD::YELLOW, LCD::MAGENTA, LCD::GREEN, LCD::ORANGE, LCD::WHITE, LCD::RED]
BG_COLORS = [LCD::BLACK, LCD::BLUE]
TEXT      = "Fablab"
SCALE     = 4
CELL      = 8 * SCALE
SUB       = "by prremote"
SUB_SCALE = 1
SUB_CELL  = 8 * SUB_SCALE
GAP = 10
X  = (lcd.width - (TEXT.length * CELL)) / 2
X2 = (lcd.width - (SUB.length * SUB_CELL)) / 2
Y  = (lcd.height - (CELL + GAP + SUB_CELL)) / 2
Y2 = Y + CELL + GAP

def show(lcd, fg, bg)
  lcd.fill(bg)
  lcd.text(X, Y, TEXT, color: fg, bg: bg, scale: SCALE)
  lcd.text(X2, Y2, SUB, color: fg, bg: bg, scale: SUB_SCALE)
end

def blink(lcd, flash, fg, bg)
  3.times do
    lcd.fill(flash)
    sleep 0.08
    lcd.fill(bg)
    sleep 0.08
  end
  show(lcd, fg, bg)
end

fg_idx = 0
bg_idx = 0
show(lcd, FG_COLORS[fg_idx], BG_COLORS[bg_idx])

loop do
  if btn_a.pressed?
    fg_idx = (fg_idx + 1) % FG_COLORS.length
    blink(lcd, FG_COLORS[fg_idx], FG_COLORS[fg_idx], BG_COLORS[bg_idx])
    sleep 0.05 while btn_a.pressed? # wait for release (debounce)
  elsif btn_b.pressed?
    bg_idx = (bg_idx + 1) % BG_COLORS.length
    blink(lcd, BG_COLORS[bg_idx], FG_COLORS[fg_idx], BG_COLORS[bg_idx])
    sleep 0.05 while btn_b.pressed?
  end
  sleep 0.02
end
