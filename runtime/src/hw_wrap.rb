# Hardware peripheral wrappers for prremote (GPIO / ADC / PWM / SPI / I2C).
#
# API design is intentionally simpler than picoruby's equivalents
# (picoruby-gpio / picoruby-adc / picoruby-pwm / picoruby-spi / picoruby-i2c).
# For example, GPIO uses a direction constant (OUT / IN / IN_PULLUP) instead of
# picoruby's bitfield flags (GPIO::OUT | GPIO::PULL_UP), and PWM uses duty_u16
# (0-65535) instead of a duty-cycle percentage.  The C primitives (_gpio_init,
# _adc_read_pin, etc.) are defined per platform — bindings.c (Pico) and
# esp32/main/bindings_esp32.c (ESP32) — and are not shared with picoruby.
#
# This file is compiled into both the Pico and the ESP32 runtimes.
# Platform differences:
#   - ADC pins: RP2040 GPIO 26-28; ESP32 GPIO 32-39 (ADC1 only)
#   - ESP32 GPIO 34-39 are input-only and have no pull resistors
#   - Temperature is RP2040-only (raises at runtime on ESP32)
#   - Default I2C pins: RP2040 SDA=4/SCL=5; ESP32 SDA=21/SCL=22
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
    @pin = pin
    _adc_init(pin)
  end

  def read
    _adc_read_pin(@pin) << 4  # scale 12-bit (0-4095) → 16-bit (0-65520)
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

class SPI
  MSB_FIRST         = 1
  DEFAULT_FREQUENCY = 1_000_000

  # Accepts 0 / 1, :SPI0 / :SPI1, or the legacy :RP2040_SPI0 / :RP2040_SPI1.
  def self.unit_num(unit)
    return unit if unit == 0 || unit == 1

    (unit == :SPI1 || unit == :RP2040_SPI1) ? 1 : 0
  end

  def initialize(unit: 0, frequency: DEFAULT_FREQUENCY, sck_pin: -1, cipo_pin: -1, copi_pin: -1, cs_pin: -1, mode: 0)
    @unit_num = _spi_init(SPI.unit_num(unit), frequency, sck_pin, cipo_pin, copi_pin, mode)
    if cs_pin >= 0
      @cs = GPIO.new(cs_pin, GPIO::OUT)
      @cs.write(1)
    end
  end

  # write(byte, byte, ...) → bytes written
  def write(*data)
    _spi_write(@unit_num, data)
  end

  # read(len, repeated_tx_data = 0) → String or nil
  def read(len, repeated_tx_data = 0)
    _spi_read(@unit_num, len, repeated_tx_data)
  end

  # transfer(data_array) → String or nil  (full-duplex write+read)
  def transfer(data)
    _spi_transfer(@unit_num, data)
  end

  def select
    @cs.write(0) if @cs
  end

  def deselect
    @cs.write(1) if @cs
  end
end

# On-chip temperature sensor (ADC channel 4, internal — no GPIO pin needed).
# RP2040-only: raises a RuntimeError on ESP32.
# RP2040 datasheet §4.9.5: T(°C) = 27 - (Vbe - 0.706) / 0.001721
# where Vbe = raw_12bit * 3.3 / 4096.
class Temperature
  CHANNEL = 4

  def initialize
    _adc_temp_enable
  end

  # Returns raw 12-bit ADC reading (0-4095).
  def read
    _adc_select_input(CHANNEL)
    _adc_read
  end

  def celsius
    raw = read
    vbe = raw * 3.3 / 4096.0
    27.0 - (vbe - 0.706) / 0.001721
  end

  def fahrenheit
    celsius * 9.0 / 5.0 + 32.0
  end
end

class I2C
  DEFAULT_FREQUENCY = 100_000
  DEFAULT_TIMEOUT   = 500

  # Accepts 0 / 1, :I2C0 / :I2C1, or the legacy :RP2040_I2C0 / :RP2040_I2C1.
  def self.unit_num(unit)
    return unit if unit == 0 || unit == 1

    (unit == :I2C1 || unit == :RP2040_I2C1) ? 1 : 0
  end

  def initialize(unit: 0, frequency: DEFAULT_FREQUENCY, sda_pin: -1, scl_pin: -1, timeout: DEFAULT_TIMEOUT)
    @timeout  = timeout
    @unit_num = _i2c_init(I2C.unit_num(unit), frequency, sda_pin, scl_pin)
  end

  # write(addr, byte, byte, ...) → bytes written or -1
  def write(addr, *data)
    _i2c_write(@unit_num, addr, data, 0)
  end

  # read(addr, len, *write_data) → String or nil
  # If write_data is given, writes it first with repeated-start then reads.
  def read(addr, len, *write_data)
    _i2c_write(@unit_num, addr, write_data, 1) unless write_data.empty?
    _i2c_read(@unit_num, addr, len)
  end

  # scan → Array of 7-bit addresses that responded
  def scan
    found = []
    addr = 0x08
    while addr <= 0x77
      result = _i2c_read(@unit_num, addr, 1)
      found << addr unless result.nil?
      addr += 1
    end
    found
  end
end

class Integer
  def zero?
    self == 0
  end
end
