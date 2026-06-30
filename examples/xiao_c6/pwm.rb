# Device: Seeed Studio XIAO ESP32C6 — breathe (fade in/out) the onboard LED.
# No external wiring needed. The onboard yellow user LED is on GPIO 15.
#
# The LED is active-low: a HIGH duty drives it dim, a LOW duty drives it bright.
# We invert in software (bright = 65535 - level) so the value we ramp matches the
# perceived brightness. To breathe an external LED instead, wire it + a 330Ohm
# resistor between any free D pin and GND and drop the inversion.
#
# ESP32-C6 LEDC has 6 PWM channels; one is used here.

PIN = 15

# Start fully off. duty_u16 = 65535 is "off" for the active-low onboard LED.
pwm = PWM.new(PIN, frequency: 1000, duty_u16: 65_535)

def set_brightness(pwm, level)
  # Invert so 0 = off, 65535 = full brightness on the active-low LED.
  pwm.duty_u16 = 65_535 - level
end

puts "Breathing the onboard LED (Ctrl-C to stop)..."
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
