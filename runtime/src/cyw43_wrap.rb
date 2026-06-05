# CYW43 module — prremote-specific API.
# Auth constants are taken from picoruby-cyw43 (mrbgems/picoruby-cyw43/mrblib/cyw43.rb).
# C primitives (_cyw43_*, _wifi_*) are defined in bindings_cyw43.c.
module CYW43
  # Constants copied from picoruby-cyw43/mrblib/cyw43.rb.
  class Auth
    OPEN           = 0
    WPA_TKIP_PSK   = 0x00200002
    WPA2_AES_PSK   = 0x00400004
    WPA2_MIXED_PSK = 0x00400006
  end

  def self.init(country = nil)
    _cyw43_init(country)
  end

  def self.initialized?
    _cyw43_initialized
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
    class ConnectTimeout < RuntimeError; end
    class ConnectError   < RuntimeError; end

    # Link status codes from cyw43_ll.h (cyw43_tcpip_link_status return values).
    LINK_DOWN    =  0
    LINK_JOIN    =  1
    LINK_NOIP    =  2
    LINK_UP      =  3
    LINK_FAIL    = -1
    LINK_NONET   = -2
    LINK_BADAUTH = -3

    # Raises ConnectError on connection-level failure (bad auth, AP not found, etc.)
    # Raises ConnectTimeout when the timeout expires without success.
    # If the chip is already connected, the existing session is reused and no
    # re-authentication occurs. Call disconnect explicitly before reconnecting.
    def self.connect(ssid, pass, auth = CYW43::Auth::WPA2_AES_PSK, timeout = 60)
      _cyw43_enable_sta_mode
      result = _wifi_connect(ssid, pass, auth, timeout * 1000)
      return if result == 0
      status = _wifi_link_status
      if status == LINK_BADAUTH
        raise ConnectError, "Authentication failed"
      elsif status < 0
        raise ConnectError, "Connection failed (status: #{status})"
      else
        raise ConnectTimeout, "WiFi connect timed out"
      end
    end

    def self.disconnect
      _wifi_disconnect
    end

    def self.link_status
      _wifi_link_status
    end

    def self.ipv4_address
      _wifi_ipv4_address
    end

    def self.ipv4_netmask
      _wifi_ipv4_netmask
    end

    def self.ipv4_gateway
      _wifi_ipv4_gateway
    end
  end
end
