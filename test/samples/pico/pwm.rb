# Device: Pico / Pico W
# PWM: fade an LED on GPIO 15
# Connect LED + resistor (330Ω) between GPIO15 and GND.
pwm = PWM.new(15, frequency: 1000, duty_u16: 0)

puts "Fading up..."
i = 0
while i <= 65_535
  pwm.duty_u16 = i
  sleep 0.01
  i += 655
end

puts "Fading down..."
i = 65_535
while i >= 0
  pwm.duty_u16 = i
  sleep 0.01
  i -= 655
end

pwm.duty_u16 = 0
puts "done"
