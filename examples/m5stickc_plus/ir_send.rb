# Device: M5StickC PLUS (ESP32-PICO-D4)
# Send NEC infrared remote-control codes from the built-in IR LED (GPIO9)
# — no wiring needed. The IR LED sits on the top edge next to the red LED.
#
# Checking that it works:
#   - Point a smartphone camera at the top edge: most cameras show the IR
#     LED flickering purple/white while it transmits (some iPhone rear
#     cameras filter IR — try the front camera).
#   - Or aim at a device that takes NEC codes and set ADDRESS/COMMAND to one
#     of its buttons (many cheap LED strips / Arduino kit remotes use NEC,
#     address 0x00). The red LED (GPIO10) flashes with each frame.
#
# IR is classic-ESP32 only: frames are replayed by the RMT peripheral on a
# 38 kHz carrier, so pulse timing is exact regardless of the Ruby VM.

ADDRESS = 0x00
COMMAND = 0x45

ir  = IR.new(9)
led = GPIO.new(10, GPIO::OUT)

puts "Sending NEC address=0x#{ADDRESS.to_s(16)} command=0x#{COMMAND.to_s(16)} x10..."
10.times do
  led.write 0
  ir.send_nec(ADDRESS, COMMAND)
  led.write 1
  sleep 1
end
puts "done"
