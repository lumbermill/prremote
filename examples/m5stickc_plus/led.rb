# Device: M5StickC PLUS (ESP32-PICO-D4)
# Blink the red LED on the top edge — no wiring needed.
# The LED is on GPIO10 and is active-low (write 0 = on, 1 = off).
# GPIO.led is not wired up for this board (the esp32 runtime is shared with
# the M5GO, which has no single-color LED), so drive the pin directly.
led = GPIO.new(10, GPIO::OUT)

puts "Blinking the red LED 10 times..."
10.times do
  led.write 0 # on
  sleep 0.25
  led.write 1 # off
  sleep 0.25
end
puts "done"
