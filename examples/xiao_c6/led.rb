# Device: Seeed Studio XIAO ESP32C6 — blinks the onboard user LED via GPIO.led.
# The user LED is on GPIO 15 and is active-low; GPIO.led hides the inversion,
# so write(1) turns it on. The same GPIO.led code works on every board.
led = GPIO.led
5.times do
  led.write 1
  sleep 0.5
  led.write 0
  sleep 0.5
end
