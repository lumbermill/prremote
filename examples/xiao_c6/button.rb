# Device: Seeed Studio XIAO ESP32C6
# Read the button — no wiring needed.
btn_boot = GPIO.new(9, GPIO::IN)

puts "Press B botton (reading for 15 s)..."
150.times do
  pressed = ""
  pressed += "B" if btn_boot.read == 0
  puts pressed unless pressed.empty?
  sleep 0.1
end
puts "done"
