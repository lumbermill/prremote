# Device: Pico family (Pico / Pico 2 / Pico W / Pico 2 W) — blinks the onboard LED.
# GPIO.led is board-neutral: on the plain Pico / Pico 2 it maps to GPIO 25; on the
# Pico W / Pico 2 W the LED hangs off the CYW43 wireless chip, which GPIO.led powers
# up on first use automatically (no WiFi connection is made).
led = GPIO.led
5.times do
  led.write 1
  sleep 0.5
  led.write 0
  sleep 0.5
end
