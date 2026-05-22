# Device: Pico / Pico W
# Multi-file demo: uses Blinker class defined in blinker.rb
# Wiring: LED + 330Ω resistor between GPIO15 and GND
#
# Run:
#   prremote run test/samples/multi/blinker.rb test/samples/multi/main.rb
b = Blinker.new(15)

puts "3 blinks (fast)..."
b.blink(3, interval: 0.1)
sleep 0.5

puts "5 blinks (slow)..."
b.blink(5, interval: 0.4)

puts "done"
