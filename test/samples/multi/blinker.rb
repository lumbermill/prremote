# Device: Pico / Pico W
# Blinker: reusable LED class loaded before main.rb
# Wiring: LED + 330Ω resistor between the target GPIO pin and GND
#
# Run both files together (blinker.rb must come first):
#   prremote run test/samples/multi/blinker.rb test/samples/multi/main.rb
class Blinker
  def initialize(pin)
    @led = GPIO.new(pin, :output)
  end

  def on  = @led.write(1)
  def off = @led.write(0)

  def blink(times, interval: 0.2)
    times.times do
      @led.write(1)
      sleep interval
      @led.write(0)
      sleep interval
    end
  end
end
