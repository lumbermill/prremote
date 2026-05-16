class GPIO
  IN          = 0
  OUT         = 1
  IN_PULLUP   = 2
  IN_PULLDOWN = 3

  def initialize(pin, direction = OUT)
    @pin = pin
    _gpio_init(pin)
    if direction == OUT
      _gpio_set_dir(pin, 1)
    else
      _gpio_set_dir(pin, 0)
      _gpio_pull_up(pin)   if direction == IN_PULLUP
      _gpio_pull_down(pin) if direction == IN_PULLDOWN
    end
  end

  def write(val)
    _gpio_put(@pin, val)
  end

  def read
    _gpio_get(@pin)
  end
end

class ADC
  def initialize(pin)
    @pin     = pin
    @channel = pin - 26  # GPIO26=ADC0, GPIO27=ADC1, GPIO28=ADC2
    _adc_init(pin)
  end

  def read
    _adc_select_input(@channel)
    _adc_read << 4  # scale 12-bit (0-4095) → 16-bit (0-65520)
  end
end

class PWM
  def initialize(pin, frequency: 1000, duty_u16: 0)
    @pin = pin
    _pwm_gpio_init(pin)
    _pwm_set_freq(pin, frequency)
    _pwm_set_duty_u16(pin, duty_u16)
  end

  def frequency=(hz)
    _pwm_set_freq(@pin, hz)
  end

  def duty_u16=(val)
    _pwm_set_duty_u16(@pin, val)
  end
end
