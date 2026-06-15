# Device: M5GO / M5Stack Core (ESP32)
# Counts motion events using M5Stack MOTION SENSOR (PIR) unit.
# Wiring: MOTION SENSOR → PORT B (Grove, black side connector)
#   Yellow wire → GPIO36 (input-only, no internal pull — PIR drives output actively)
#   Red → 5V, Black → GND
#   PIR signal: HIGH = motion detected, LOW = idle
# BtnA (GPIO39): reset counter

pir   = GPIO.new(36, GPIO::IN)
btn_a = GPIO.new(39, GPIO::IN)

lcd = LCD.new
lcd.fill(LCD::BLACK)
lcd.text(10, 10,  "MOTION COUNTER", color: LCD::WHITE, scale: 2)
lcd.text(10, 218, "BtnA: reset",    color: LCD::CYAN,  scale: 1)

count    = 0
prev_pir = 0
prev_btn = 1

def draw_count(lcd, n)
  s = n.to_s
  # center text: scale=6 → 48 px per character (8 × 6)
  x = (320 - (s.length * 48)) / 2
  lcd.fill_rect(0, 65, 320, 80, LCD::BLACK)
  lcd.text(x, 70, s, color: LCD::YELLOW, scale: 6)
end

draw_count(lcd, 0)

loop do
  cur_pir = pir.read

  if cur_pir == 1 && prev_pir == 0        # rising edge: motion started
    count += 1
    draw_count(lcd, count)
    lcd.fill_rect(0, 155, 320, 36, LCD::RED)
    lcd.text(90, 162, "Motion!", color: LCD::WHITE, scale: 2)
  elsif cur_pir == 0 && prev_pir == 1     # falling edge: motion ended
    lcd.fill_rect(0, 155, 320, 36, LCD::BLACK)
  end
  prev_pir = cur_pir

  cur_btn = btn_a.read
  if cur_btn == 0 && prev_btn == 1        # button pressed: reset
    count = 0
    draw_count(lcd, 0)
    lcd.fill_rect(0, 155, 320, 36, LCD::BLACK)
  end
  prev_btn = cur_btn

  sleep 0.02
end
