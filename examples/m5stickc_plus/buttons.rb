# Device: M5StickC PLUS (ESP32-PICO-D4)
# Read the two front/side buttons — no wiring needed.
# BtnA: GPIO37 (big front button). BtnB: GPIO39 (side button, opposite the
# power button on the top edge). Both are input-only pins (GPIO34-39 have
# no internal pull resistor on ESP32) with an external pull-up on the
# board, so plain GPIO::IN; pressed reads 0.
btn_a = GPIO.new(37, GPIO::IN)
btn_b = GPIO.new(39, GPIO::IN)

puts "Press buttons A / B (reading for 15 s)..."
150.times do
  pressed = ""
  pressed += "A" if btn_a.read == 0
  pressed += "B" if btn_b.read == 0
  puts pressed unless pressed.empty?
  sleep 0.1
end
puts "done"
