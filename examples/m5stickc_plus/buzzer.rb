# Device: M5StickC PLUS (ESP32-PICO-D4)
# Play a C-major scale on the built-in passive buzzer (GPIO2) with PWM —
# no wiring needed. Pitch = PWM frequency, volume = duty (50% is loudest).

BUZZER = 2
SCALE  = [262, 294, 330, 349, 392, 440, 494, 523] # C4 .. C5 (Hz)

pwm = PWM.new(BUZZER, frequency: SCALE[0], duty_u16: 0)

puts "Playing a C-major scale..."
SCALE.each do |hz|
  pwm.frequency = hz
  pwm.duty_u16 = 32_768
  sleep 0.3
  pwm.duty_u16 = 0
  sleep 0.05
end
puts "done"
