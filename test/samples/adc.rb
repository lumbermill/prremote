# Device: Pico / Pico W
# ADC: read an analog sensor on GPIO 26 (ADC0)
# GPIO26 = ADC0, GPIO27 = ADC1, GPIO28 = ADC2
# read returns a 16-bit value (0-65535).
adc = ADC.new(26)

puts "Reading ADC0 (GPIO26) — 10 samples:"
10.times do |i|
  val  = adc.read
  volt = val * 3.3 / 65535
  puts "#{i}: #{val} (#{volt} V)"
  sleep 0.5
end
