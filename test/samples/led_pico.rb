# Device: Pico (no W) — GPIO 25 onboard LED
led = GPIO.new(25, GPIO::OUT)
5.times do
  led.write 1
  sleep 0.5
  led.write 0
  sleep 0.5
end
