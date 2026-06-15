# Device: M5GO / M5Stack Core (ESP32)
# Theremin: ANGLE SENSOR controls speaker pitch via PWM.
# Wiring: ANGLE SENSOR → PORT B (Grove, black side connector)
#   Yellow wire → GPIO36 (ADC1_CH0, input-only). Speaker is built-in on GPIO25.
# BtnA (GPIO39): mute / unmute    BtnC (GPIO37): exit

FREQ_MIN    = 200
FREQ_MAX    = 2000
SPEAKER_PIN = 25

lcd   = LCD.new
adc   = ADC.new(36)
btn_a = GPIO.new(39, GPIO::IN)
btn_c = GPIO.new(37, GPIO::IN)
spk   = PWM.new(SPEAKER_PIN, frequency: FREQ_MIN, duty_u16: 0)

lcd.fill(LCD::BLACK)
lcd.text(55, 10, "THEREMIN",       color: LCD::CYAN,  scale: 3)
lcd.text(10, 52, "A: mute/unmute", color: LCD::WHITE, scale: 1)
lcd.text(10, 68, "C: exit",        color: LCD::WHITE, scale: 1)

muted  = false
prev_a = 1
lcd.text(10, 90, "PLAYING", color: LCD::GREEN, scale: 2)

loop do
  break if btn_c.read == 0

  cur_a = btn_a.read
  if cur_a == 0 && prev_a == 1
    muted = !muted
    lcd.fill_rect(10, 90, 160, 20, LCD::BLACK)
    if muted
      spk.duty_u16 = 0
      lcd.text(10, 90, "MUTED  ", color: LCD::RED,   scale: 2)
    else
      lcd.text(10, 90, "PLAYING", color: LCD::GREEN, scale: 2)
    end
  end
  prev_a = cur_a

  raw  = adc.read
  freq = FREQ_MIN + (raw * (FREQ_MAX - FREQ_MIN) / 65520)
  pct  = raw * 100 / 65520

  spk.frequency = freq
  spk.duty_u16  = muted ? 0 : 2048 # 12.5% duty — louder values are painfully loud

  lcd.text(10, 135, "#{freq} Hz   ", color: LCD::YELLOW, scale: 2)
  lcd.text(10, 165, "#{pct} %     ", color: LCD::CYAN,   scale: 2)

  sleep 0.05
end

spk.duty_u16 = 0
lcd.fill(LCD::BLACK)
lcd.text(90, 108, "bye!", color: LCD::WHITE, scale: 3)
