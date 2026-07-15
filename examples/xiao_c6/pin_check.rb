# Device: Seeed Studio XIAO ESP32C6 — D-label <-> GPIO mapping self-test.
# Verifies that each silkscreened D pin really is the GPIO number we expect,
# using nothing but jumper wires between physically adjacent edge pads.
#
# Round 1 — jumper these five adjacent pairs (top of the board = USB connector):
#   left  side: D0 <-> D1,  D2 <-> D3,  D4 <-> D5
#   right side: D7 <-> D8,  D9 <-> D10
# Run the script: those five pairs should print OK (D5<->D6 prints NG — fine).
#
# Round 2 — move one jumper to D5 <-> D6 (bottom two pads on the left side)
# and run again: now the D5<->D6 line must print OK.
#
# Each pair is tested in both directions: one pin drives HIGH then LOW while
# the other reads with an internal pull-down, then the roles are swapped.
# A pair passes only if the reader follows the driver both ways, so an OK
# proves both GPIO numbers sit on the two jumpered pads.

PAIRS = [
  # [silk A, silk B, gpio A, gpio B]
  ['D0', 'D1',  0,  1],
  ['D2', 'D3',  2, 21],
  ['D4', 'D5', 22, 23],
  ['D7', 'D8', 17, 19],
  ['D9', 'D10', 20, 18],
  ['D5', 'D6', 23, 16] # round 2 only
]

# Drive `out_pin` HIGH then LOW; `in_pin` (pulled down) must follow.
def follows?(out_pin, in_pin)
  drv = GPIO.new(out_pin, GPIO::OUT)
  rcv = GPIO.new(in_pin, GPIO::IN_PULLDOWN)
  drv.write 1
  sleep 0.01
  high = rcv.read
  drv.write 0
  sleep 0.01
  low = rcv.read
  # Park the driver as a plain input so the next test never fights it.
  GPIO.new(out_pin, GPIO::IN)
  high == 1 && low == 0
end

puts 'XIAO ESP32C6 pin mapping check (jumpered pairs should print OK)'
PAIRS.each do |pair|
  gpio_a = pair[2]
  gpio_b = pair[3]
  ok = follows?(gpio_a, gpio_b) && follows?(gpio_b, gpio_a)
  label = "#{pair[0]}(GPIO#{gpio_a}) <-> #{pair[1]}(GPIO#{gpio_b})"
  puts "#{ok ? 'OK ' : 'NG '} #{label}"
end
puts 'done'
