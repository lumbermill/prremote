# M5StickC PLUS board support: power-on, LCD preset and built-in devices.
# Board library for prremote — compiled into the script by the host when it
# references M5StickCPlus (see lib/prremote/boards.rb); this file runs on the
# device (esp32 runtime) together with bm8563.rb.
#
#   stick = M5StickCPlus.new         # powers the LCD via the AXP192 PMIC
#   lcd = stick.lcd(rotation: 1)     # landscape; 0-3 all preset
#   stick.button_a.pressed?          # front button; button_b = side button
#   stick.led.on                     # red LED
#   stick.tone(440, 0.2)             # passive buzzer
#   stick.rtc.time.to_s              # BM8563 RTC (see bm8563.rb)
#   stick.ir.send_nec(0x00, 0x45)    # IR LED
#
# Built-in devices share one I2C bus (SDA=21/SCL=22): AXP192 0x34, BM8563
# 0x51, MPU6886 0x68 — use stick.i2c for anything else on it.
class M5StickCPlus
  AXP192 = 0x34

  # ST7789v2 135x240 inside a 240x320 RAM window. Per rotation: MADCTL (the
  # generic table minus its BGR bit — this panel is RGB) and the RAM offset
  # of the 135-px side, which is 52 px from one edge and 53 from the other,
  # so it changes when a rotation mirrors that axis.
  LCD_MADCTL   = [0x00, 0x60, 0xC0, 0xA0]
  LCD_OFFSET_X = [52, 53, 53, 52]

  attr_reader :i2c

  def initialize
    @i2c = I2C.new(sda_pin: 21, scl_pin: 22)
    @i2c.write(AXP192, 0x28, 0xCC)             # LDO2 (backlight) / LDO3 (panel) = 3.0V
    cur = @i2c.read(AXP192, 1, 0x12).getbyte(0)
    @i2c.write(AXP192, 0x12, cur | 0x4D)       # enable EXTEN (Grove 5V), LDO2, LDO3, DCDC1
  end

  # rotation: 0 = portrait (USB at the bottom), 1/3 = landscape, 2 = portrait
  # upside down. Returns a plain LCD (see lcd_wrap.rb for drawing methods).
  def lcd(rotation: 0)
    r = rotation % 4
    LCD.new(rotation: r, sck_pin: 13, mosi_pin: 15, miso_pin: -1, cs_pin: 5,
            dc_pin: 23, rst_pin: 18, bl_pin: -1, invert: true,
            madctl: LCD_MADCTL[r], width: 135, height: 240,
            offset_x: LCD_OFFSET_X[r], offset_y: 40)
  end

  def rtc
    @rtc ||= BM8563.new(@i2c)
  end

  # Front (big) button.
  def button_a
    @button_a ||= Button.new(37)
  end

  # Side button, opposite the power button.
  def button_b
    @button_b ||= Button.new(39)
  end

  def led
    @led ||= LED.new(10)
  end

  # Plays `hz` on the passive buzzer (GPIO2) for `duration` seconds.
  def tone(hz, duration)
    @buzzer ||= PWM.new(2, frequency: hz, duty_u16: 0)
    @buzzer.frequency = hz
    @buzzer.duty_u16 = 32_768
    sleep duration
    @buzzer.duty_u16 = 0
  end

  def ir
    @ir ||= IR.new(9)
  end

  # External pull-up on the board; pressed reads 0.
  class Button
    def initialize(pin)
      @gpio = GPIO.new(pin, GPIO::IN)
    end

    def pressed?
      @gpio.read == 0
    end
  end

  # Active-low red LED.
  class LED
    def initialize(pin)
      @gpio = GPIO.new(pin, GPIO::OUT)
      off
    end

    def on
      @gpio.write(0)
    end

    def off
      @gpio.write(1)
    end
  end
end
