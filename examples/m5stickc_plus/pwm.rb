# Device: M5StickC PLUS (ESP32-PICO-D4)
# Breathe (fade in/out) the red LED on GPIO10 with PWM — no wiring needed.
#
# The LED is active-low: duty 65535 = off, 0 = full brightness. We invert in
# software (duty = 65535 - level) so the ramped value matches brightness.

PIN = 10

pwm = PWM.new(PIN, frequency: 1000, duty_u16: 65_535) # start off

def set_brightness(pwm, level)
  pwm.duty_u16 = 65_535 - level
end

puts "Breathing the red LED..."
3.times do
  level = 0
  while level <= 65_535
    set_brightness(pwm, level)
    sleep 0.01
    level += 655
  end
  level = 65_535
  while level >= 0
    set_brightness(pwm, level)
    sleep 0.01
    level -= 655
  end
end

set_brightness(pwm, 0)
puts "done"
