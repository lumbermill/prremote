# Device: Pico / Pico W
# Temperature: read the on-chip temperature sensor (ADC channel 4, internal).
# No external wiring needed.
temp = Temperature.new

puts "On-chip temperature — 10 samples:"
10.times do |i|
  c = temp.celsius
  f = temp.fahrenheit
  puts "#{i}: #{c} C  (#{f} F)"
  sleep 1.0
end
