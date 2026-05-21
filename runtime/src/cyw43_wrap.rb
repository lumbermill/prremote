# Ruby API modelled on picoruby-cyw43:
#   mrbgems/picoruby-cyw43/mrblib/cyw43.rb
# Method names, Auth constants, and ConnectTimeout are taken directly from
# that file so user scripts are portable between prremote and picoruby.
# The underlying C primitives (_cyw43_*, _wifi_*) differ — they are defined
# in bindings_cyw43.c against the plain mruby/c ABI instead of picoruby.
module CYW43
  class ConnectTimeout < RuntimeError; end

  # Copied from picoruby-cyw43/mrblib/cyw43.rb (CYW43::Auth).
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

  # connect_timeout(ssid, pass, auth = Auth::WPA2_AES_PSK, timeout_sec = 60)
  # Raises CYW43::ConnectTimeout on failure.
  def self.connect_timeout(ssid, pass, auth = Auth::WPA2_AES_PSK, timeout = 60)
    result = _wifi_connect(ssid, pass, auth, timeout * 1000)
    raise CYW43::ConnectTimeout, "WiFi connect failed" if result != 0
  end

  def self.disconnect
    _wifi_disconnect
  end

  def self.tcpip_link_status
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
end
