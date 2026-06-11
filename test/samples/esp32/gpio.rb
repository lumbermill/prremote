# Device: M5GO / generic ESP32
# GPIO output: blink an external LED on GPIO 26 (M5GO Port B, white wire)
# Connect LED + resistor (330Ω) between GPIO26 and GND.
# Note: GPIO 34-39 are input-only on ESP32 — they cannot drive an LED.
led = GPIO.new(26, GPIO::OUT)
5.times do
  led.write 1
  sleep 0.5
  led.write 0
  sleep 0.5
end

# GPIO input: read a button between GPIO 36 (M5GO Port B, yellow wire) and GND.
# GPIO 34-39 have no internal pull resistors; add an external pull-up
# (e.g. 10 kΩ to 3.3 V) or use a pin below 34 with GPIO::IN_PULLUP.
btn = GPIO.new(36, GPIO::IN)
puts "Press the button (reading for 5 s)..."
50.times do
  puts "pressed" if btn.read.zero?
  sleep 0.1
end
