# Device: Seeed Studio XIAO ESP32C6
# GPIO output: blink the onboard yellow user LED (GPIO 15, active-low).
# No external wiring needed.
#
# The onboard LED is active-low: write 0 to turn on, 1 to turn off.
# GPIO 15 is labeled D13 on the XIAO ESP32C6 pinout.

led = GPIO.new(15, GPIO::OUT)
5.times do
  led.write 0   # on
  sleep 0.5
  led.write 1   # off
  sleep 0.5
end

# GPIO input: read a button connected between GPIO 2 (D0) and GND.
# GPIO 2 has an internal pull-up; reads 1 when open, 0 when pressed.
btn = GPIO.new(2, GPIO::IN_PULLUP)
puts "Press the button (reading for 5 s)..."
50.times do
  puts "pressed" if btn.read.zero?
  sleep 0.1
end
