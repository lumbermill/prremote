# Device: Pico W only (uses CYW43 onboard LED)
CYW43.init
led = CYW43::GPIO.new(CYW43::GPIO::LED_PIN)
5.times do
  led.write 1
  sleep 0.5
  led.write 0
  sleep 0.5
end
