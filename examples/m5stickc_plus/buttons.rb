# Device: M5StickC PLUS (ESP32-PICO-D4)
# Read the front button — no wiring needed.
# BtnA: GPIO37 (big front button, input-only pin with an external pull-up
# on the board). Confirmed on physical hardware; reads 0 when pressed.
#
# Button B is intentionally omitted: sources disagree on its pin (the
# M5Stack Arduino library's Config.h says GPIO39; other docs say GPIO2) and
# neither was confirmed pressing the side button on a physical unit in this
# session. Whoever adds it should re-probe on hardware before trusting either
# value.
btn_a = GPIO.new(37, GPIO::IN)

puts "Press button A (reading for 15 s)..."
150.times do
  puts "A" if btn_a.read == 0
  sleep 0.1
end
puts "done"
