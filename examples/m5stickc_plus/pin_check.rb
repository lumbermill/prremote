# Device: M5StickC PLUS (ESP32-PICO-D4) — external pin <-> GPIO self-test.
# Verifies that the header and Grove pins really are the GPIOs we expect,
# using nothing but jumper wires.
#
# 8-pin header (labels are printed on the case next to it):
#   GND  5V  G26  G36/G25  G0  BAT  3V3  5V-IN
# (G36 and G25 share one pad; G36 is input-only.)
# Grove port (HY2.0-4P): GND  5V  G32  G33
#
# Round 1 — jumper G26 <-> G36/G25 on the header and G32 <-> G33 on the
# Grove port (plug a Grove cable in and short its yellow/white wires).
# Run the script: the G26 and G32/G33 lines print OK (G0 lines print NG — fine).
#
# Round 2 — move the header jumper to G36/G25 <-> G0 and run again:
# now the G0 lines must print OK.
#
# Each pair is tested in both directions where both pins can drive: one pin
# drives HIGH then LOW while the other reads, then the roles are swapped.
# GPIO36 is input-only, so it is only ever the reader.

PAIRS = [
  # [label, gpio A, gpio B, bidirectional?]
  ['Grove G32 <-> G33',   32, 33, true],
  ['G26 <-> G25 (pad)',   26, 25, true],
  ['G26 -> G36 (pad)',    26, 36, false],
  ['G0 <-> G25 (pad)',     0, 25, true], # round 2 only
  ['G0 -> G36 (pad)',      0, 36, false] # round 2 only
]

# Drive `out_pin` HIGH then LOW; `in_pin` must follow. GPIO34-39 have no
# internal pull resistors, so they read as plain inputs.
def follows?(out_pin, in_pin)
  drv = GPIO.new(out_pin, GPIO::OUT)
  rcv = GPIO.new(in_pin, in_pin >= 34 ? GPIO::IN : GPIO::IN_PULLDOWN)
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

puts 'M5StickC PLUS pin check (jumpered pairs should print OK)'
PAIRS.each do |pair|
  a = pair[1]
  b = pair[2]
  ok = follows?(a, b)
  ok &&= follows?(b, a) if pair[3]
  puts "#{ok ? 'OK ' : 'NG '} #{pair[0]}"
end
puts 'done'
