# Device: Pico / Pico W
# GPIO output: blink an external LED on GPIO 15
# Connect LED + resistor (330Ω) between GPIO15 and GND.
led = GPIO.new(15, GPIO::OUT)
5.times do
  led.write 1
  sleep 0.5
  led.write 0
  sleep 0.5
end

# GPIO input with pull-up: read a button on GPIO 14
# Connect button between GPIO14 and GND.
btn = GPIO.new(14, GPIO::IN_PULLUP)
puts "Press the button (reading for 5 s)..."
50.times do
  if btn.read.zero?
    puts "pressed"
    led.write 1
  else
    puts "released"
    led.write 0
  end
  sleep 0.1
end
