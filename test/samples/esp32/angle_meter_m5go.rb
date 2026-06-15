# Device: M5GO / M5Stack Core (ESP32)
# Analog bar meter using M5Stack ANGLE SENSOR unit.
# Wiring: ANGLE SENSOR → PORT B (Grove, black side connector)
#   Yellow wire → GPIO36 (ADC1_CH0, input-only, no internal pull needed)
#   Red → 5V, Black → GND
# ADC.read returns 0-65520 (12-bit × 16).
# Note: the ANGLE SENSOR's potentiometer does not cover the full ADC range;
# the practical maximum is ~90-92% due to mechanical travel and ADC non-linearity.

BAR_X = 20
BAR_Y = 90
BAR_W = 280
BAR_H = 50
GRAY  = LCD.rgb(60, 60, 60)

lcd = LCD.new
lcd.fill(LCD::BLACK)
lcd.text(10, 10, "ANGLE SENSOR",  color: LCD::WHITE, scale: 2)
lcd.text(10, 40, "PORT B GPIO36", color: LCD::CYAN,  scale: 1)

# Gray border around bar
lcd.fill_rect(BAR_X - 2, BAR_Y - 2, BAR_W + 4, BAR_H + 4, GRAY)

adc = ADC.new(36)

loop do
  raw   = adc.read                  # 0-65520
  pct   = raw * 100 / 65520         # 0-100
  bar_w = raw * BAR_W / 65520

  # Draw green first, then black remainder — avoids full-bar erase flicker
  lcd.fill_rect(BAR_X,          BAR_Y, bar_w,          BAR_H, LCD::GREEN) if bar_w > 0
  lcd.fill_rect(BAR_X + bar_w,  BAR_Y, BAR_W - bar_w,  BAR_H, LCD::BLACK) if bar_w < BAR_W

  lcd.text(90, 160, "#{pct} %   ", color: LCD::YELLOW, scale: 4)
  sleep 0.05
end
