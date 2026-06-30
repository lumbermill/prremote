# WiFi module — prremote's chip-neutral wireless API.
#
# This file is still named cyw43_wrap.rb for historical reasons: the public API
# used to be a `CYW43` module, after the Infineon CYW43439 chip on the Pico W.
# The same API now also backs ESP32's built-in WiFi (esp_wifi), so the chip name
# was misleading — the public module is now `WiFi`. The underlying C primitives
# (_cyw43_*, _wifi_*) keep their historical names; they are internal and never
# referenced by user scripts.
#
# Auth constants are taken from picoruby-cyw43 (mrbgems/picoruby-cyw43/mrblib/cyw43.rb).
# C primitives (_cyw43_*, _wifi_*) are defined in bindings_cyw43.c (Pico) and
# bindings_wifi_esp32.c (ESP32).
module WiFi
  # Constants copied from picoruby-cyw43/mrblib/cyw43.rb.
  class Auth
    OPEN           = 0
    WPA_TKIP_PSK   = 0x00200002
    WPA2_AES_PSK   = 0x00400004
    WPA2_MIXED_PSK = 0x00400006
  end

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

  # Raises ConnectError on connection-level failure (bad auth, AP not found, etc.)
  # Raises ConnectTimeout when the timeout expires without success.
  # If the chip is already connected, the existing session is reused and no
  # re-authentication occurs. Call disconnect explicitly before reconnecting.
  def self.connect(ssid, pass, auth = WiFi::Auth::WPA2_AES_PSK, timeout = 60)
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
