# Device: M5GO / M5Stack Core (ESP32)
# Read the three front buttons — no wiring needed.
# BtnA: GPIO39, BtnB: GPIO38, BtnC: GPIO37 (input-only pins with external
# pull-ups, so plain GPIO::IN; pressed reads 0).
btn_a = GPIO.new(39, GPIO::IN)
btn_b = GPIO.new(38, GPIO::IN)
btn_c = GPIO.new(37, GPIO::IN)

puts "Press buttons A / B / C (reading for 15 s)..."
150.times do
  pressed = ""
  pressed += "A" if btn_a.read.zero?
  pressed += "B" if btn_b.read.zero?
  pressed += "C" if btn_c.read.zero?
  puts pressed unless pressed.empty?
  sleep 0.1
end
puts "done"
