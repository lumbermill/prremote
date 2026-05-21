module CYW43
  def self.init
    _cyw43_init
  end

  def self.enable_sta_mode
    _cyw43_enable_sta_mode
  end

  def self.disable_sta_mode
    _cyw43_disable_sta_mode
  end

  class GPIO
    LED_PIN = 0

    def initialize(pin)
      @pin = pin
    end

    def write(val)
      _cyw43_gpio_put(@pin, val)
    end

    def read
      _cyw43_gpio_get(@pin) != 0
    end
  end

  module WiFi
    LINK_UP = 3

    def self.connect(ssid, pass, timeout: 10_000)
      _cyw43_enable_sta_mode
      _wifi_connect(ssid, pass, timeout)
    end

    def self.disconnect
      _wifi_disconnect
    end

    def self.link_status
      _wifi_link_status
    end

    def self.ip_address
      _wifi_ipv4_address
    end

    def self.netmask
      _wifi_ipv4_netmask
    end

    def self.gateway
      _wifi_ipv4_gateway
    end
  end
end
