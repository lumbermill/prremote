# Device: M5StickC PLUS (ESP32-PICO-D4)
# "Ruby" with a small gem icon, filling the screen in landscape — a
# fablab.rb variant. The current time (HH:MM, from the built-in RTC) sits
# small at the top center and the runtime version at the bottom right.
# Press button A to blink the text to a new color; press button B to blink
# the background instead.
#
# Wiring: none — everything built-in (M5StickCPlus: see lcd_hello.rb).
# The clock reads the BM8563 RTC, so set it once with rtc_sync.rb (NTP);
# until then it shows "--:--". The version needs runtime 0.4.1 or later
# (PRREMOTE_VERSION); on older runtimes it is simply left out.

stick = M5StickCPlus.new
# Landscape, flipped 180° from the original version of this sample (which
# used rotation: 3) — change to 3 to flip it back.
lcd = stick.lcd(rotation: 1)
btn_a = stick.button_a
btn_b = stick.button_b

FG_COLORS = [LCD::RED, LCD::CYAN, LCD::YELLOW, LCD::MAGENTA, LCD::GREEN, LCD::ORANGE, LCD::WHITE]
BG_COLORS = [LCD::BLACK, LCD::BLUE]
TEXT      = "Ruby"
SCALE     = 4
CELL      = 8 * SCALE
SUB       = "by prremote"
SUB_SCALE = 1
SUB_CELL  = 8 * SUB_SCALE
GAP = 10

ICON_W   = 32
ICON_H   = 24
ICON_GAP = 8

TEXT_W = TEXT.length * CELL
ROW_W  = ICON_W + ICON_GAP + TEXT_W
ROW_X  = (lcd.width - ROW_W) / 2
ICON_X = ROW_X
TEXT_X = ROW_X + ICON_W + ICON_GAP

Y      = (lcd.height - (CELL + GAP + SUB_CELL)) / 2
Y2     = Y + CELL + GAP
ICON_Y = Y + ((CELL - ICON_H) / 2)
X2     = (lcd.width - (SUB.length * SUB_CELL)) / 2

MARGIN  = 4
CLOCK_X = (lcd.width - (5 * SUB_CELL)) / 2 # "HH:MM"
CLOCK_Y = MARGIN

# PRREMOTE_VERSION exists from runtime 0.4.1; nil (not shown) before that.
VER_TEXT = begin
  "v#{PRREMOTE_VERSION}"
rescue NameError
  nil
end
VER_X = VER_TEXT ? lcd.width - (VER_TEXT.length * SUB_CELL) - MARGIN : 0
VER_Y = lcd.height - SUB_CELL - MARGIN

def p2(n)
  n < 10 ? "0#{n}" : n.to_s
end

# "HH:MM" from the built-in RTC, or "--:--" if it was never set.
def clock_text(rtc)
  return "--:--" unless rtc.valid?

  t = rtc.time
  "#{p2(t.hour)}:#{p2(t.min)}"
end

# Small faceted gem: flat top crown widening to the shoulder, then
# tapering to a point — same idea as the ntp_clock.rb (M5GO) logo, halved.
def draw_gem(lcd, x, y, color)
  lcd.fill_rect(x + 10, y,      12, 3, color)
  lcd.fill_rect(x + 6,  y + 3,  20, 3, color)
  lcd.fill_rect(x + 2,  y + 6,  28, 5, color)
  lcd.fill_rect(x + 4,  y + 11, 24, 4, color)
  lcd.fill_rect(x + 8,  y + 15, 16, 4, color)
  lcd.fill_rect(x + 12, y + 19, 8,  3, color)
  lcd.fill_rect(x + 14, y + 22, 4,  2, color)
end

def draw_clock(lcd, text, fg, bg)
  lcd.text(CLOCK_X, CLOCK_Y, text, color: fg, bg: bg, scale: SUB_SCALE)
end

def show(lcd, fg, bg, clock)
  lcd.fill(bg)
  draw_gem(lcd, ICON_X, ICON_Y, fg)
  lcd.text(TEXT_X, Y, TEXT, color: fg, bg: bg, scale: SCALE)
  lcd.text(X2, Y2, SUB, color: fg, bg: bg, scale: SUB_SCALE)
  draw_clock(lcd, clock, fg, bg)
  lcd.text(VER_X, VER_Y, VER_TEXT, color: fg, bg: bg, scale: SUB_SCALE) if VER_TEXT
end

def blink(lcd, flash, fg, bg, clock)
  3.times do
    lcd.fill(flash)
    sleep 0.08
    lcd.fill(bg)
    sleep 0.08
  end
  show(lcd, fg, bg, clock)
end

fg_idx = 0
bg_idx = 0
clock = clock_text(stick.rtc)
show(lcd, FG_COLORS[fg_idx], BG_COLORS[bg_idx], clock)
next_poll = uptime_ms + 1000

loop do
  if btn_a.pressed?
    fg_idx = (fg_idx + 1) % FG_COLORS.length
    blink(lcd, FG_COLORS[fg_idx], FG_COLORS[fg_idx], BG_COLORS[bg_idx], clock)
    sleep 0.05 while btn_a.pressed? # wait for release (debounce)
  elsif btn_b.pressed?
    bg_idx = (bg_idx + 1) % BG_COLORS.length
    blink(lcd, BG_COLORS[bg_idx], FG_COLORS[fg_idx], BG_COLORS[bg_idx], clock)
    sleep 0.05 while btn_b.pressed?
  end

  # Poll the RTC once a second; redraw only the clock when the minute changes.
  if uptime_ms >= next_poll
    next_poll = uptime_ms + 1000
    now = clock_text(stick.rtc)
    if now != clock
      clock = now
      draw_clock(lcd, clock, FG_COLORS[fg_idx], BG_COLORS[bg_idx])
    end
  end
  sleep 0.02
end
