# Device: M5GO / M5Stack Core (ESP32)
# Whack-a-Mole: press A/B/C when the mole appears in the matching column.
# BtnA (GPIO39): left column, BtnB (GPIO38): center, BtnC (GPIO37): right.
# After GAME OVER, press any button to play again. No wiring needed.

ROUNDS      = 20
MOLE_SECS   = 0.8 # seconds a mole stays visible before it counts as a miss
MOLE_STEPS  = (MOLE_SECS / 0.02).to_i
SPEAKER_PIN = 25
VOL         = 2048 # 6.25% duty — keeps volume reasonable on the built-in speaker

LANE_X  = [10, 110, 210]
LANE_Y  = 60
LANE_W  = 90
LANE_H  = 100
DIVIDER = LCD.rgb(60, 60, 60)

btn_a = GPIO.new(39, GPIO::IN)
btn_b = GPIO.new(38, GPIO::IN)
btn_c = GPIO.new(37, GPIO::IN)
spk   = PWM.new(SPEAKER_PIN, frequency: 440, duty_u16: 0)
lcd   = LCD.new

def beep(spk, freq, duration)
  spk.frequency = freq
  spk.duty_u16  = VOL
  sleep duration
  spk.duty_u16  = 0
end

def wait_for_press(btn_a, btn_b, btn_c)
  prev_a = btn_a.read
  prev_b = btn_b.read
  prev_c = btn_c.read
  t      = 0
  while t < MOLE_STEPS
    cur_a = btn_a.read
    cur_b = btn_b.read
    cur_c = btn_c.read
    return 0 if cur_a == 0 && prev_a == 1
    return 1 if cur_b == 0 && prev_b == 1
    return 2 if cur_c == 0 && prev_c == 1

    prev_a = cur_a
    prev_b = cur_b
    prev_c = cur_c
    sleep 0.02
    t += 1
  end
  -1
end

# --- Title / instruction screen (shown once at startup) ---
lcd.fill(LCD::BLACK)
lcd.text(50, 70,  "WHACK-A-MOLE",                  color: LCD::WHITE,  scale: 2)
lcd.text(20, 110, "A = Left   B = Mid   C = Right", color: LCD::CYAN,   scale: 1)
lcd.text(80, 145, "Starting in 3 s",                color: LCD::YELLOW, scale: 1)
sleep 3

loop do
  score = 0
  rng   = 1

  # --- Game layout ---
  lcd.fill(LCD::BLACK)
  lcd.fill_rect(105, LANE_Y, 5, LANE_H + 20, DIVIDER)
  lcd.fill_rect(205, LANE_Y, 5, LANE_H + 20, DIVIDER)
  lcd.text(44,  LANE_Y + LANE_H + 8, "A", color: LCD::CYAN, scale: 2)
  lcd.text(148, LANE_Y + LANE_H + 8, "B", color: LCD::CYAN, scale: 2)
  lcd.text(245, LANE_Y + LANE_H + 8, "C", color: LCD::CYAN, scale: 2)

  ROUNDS.times do |round|
    rng    = rng * 75 % 65537
    target = rng % 3

    lcd.text(10, 10, "Score: #{score}  Round: #{round + 1}/#{ROUNDS}   ", color: LCD::YELLOW, scale: 1)
    lcd.fill_rect(LANE_X[target], LANE_Y, LANE_W, LANE_H, LCD::GREEN)

    pressed = wait_for_press(btn_a, btn_b, btn_c)

    if pressed == target
      score += 1
      lcd.fill_rect(LANE_X[target], LANE_Y, LANE_W, LANE_H, LCD::YELLOW)
      beep(spk, 880, 0.10)  # hit: bright high tone
      sleep 0.15
    else
      lcd.fill_rect(LANE_X[target], LANE_Y, LANE_W, LANE_H, LCD::RED)
      beep(spk, 200, 0.15)  # miss: dull low tone
      sleep 0.10
    end
    lcd.fill_rect(LANE_X[target], LANE_Y, LANE_W, LANE_H, LCD::BLACK)
    sleep 0.1
  end

  # --- GAME OVER screen ---
  lcd.fill(LCD::BLACK)
  lcd.text(60, 70,  "GAME OVER",                      color: LCD::WHITE,  scale: 3)
  lcd.text(60, 130, "#{score}/#{ROUNDS}",              color: LCD::YELLOW, scale: 4)
  lcd.text(20, 205, "Press any button to play again", color: LCD::CYAN,   scale: 1)

  # Hold GAME OVER for 2 s before accepting input (prevents accidental restart)
  sleep 3
  loop { break if btn_a.read == 1 && btn_b.read == 1 && btn_c.read == 1; sleep 0.02 }
  loop { break if btn_a.read == 0 || btn_b.read == 0 || btn_c.read == 0; sleep 0.02 }
end
