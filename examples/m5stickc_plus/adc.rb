# Device: M5StickC PLUS (ESP32-PICO-D4)
# ADC: read an analog voltage on the Grove port's G33 (ADC1_CH5).
#
# Wiring (either one):
#   - M5Stack ANGLE unit (potentiometer) on the Grove port — its signal
#     lands on G33. The unit is powered from Grove 5V, which the AXP192
#     only supplies once EXTEN is on (done below).
#   - A jumper from G33 to GND (~0) or to 3V3 on the header (~65520).
# ADC.read returns 0-65520 (12-bit x 16). Verified with an ANGLE unit: the
# reading follows the knob and reaches 0 / 65520 at either end of its travel.

M5StickCPlus.new # AXP192 power-on, incl. EXTEN (Grove 5V) — see lcd_hello.rb

adc = ADC.new(33)

puts "Reading G33 — 20 samples (turn the knob / move the jumper):"
20.times do |i|
  val = adc.read
  mv  = val * 3300 / 65_520
  puts "#{i}: #{val} (~#{mv} mV)"
  sleep 0.5
end
