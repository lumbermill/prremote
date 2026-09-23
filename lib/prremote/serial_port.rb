require 'rbconfig'
require 'rubyserial'

module Prremote
  # Opening the port is not enough on Windows: rubyserial leaves DTR deasserted,
  # and a Pico's TinyUSB CDC only starts transmitting once the host raises it,
  # so the board reads as unresponsive and writes fail with ERROR_SEM_TIMEOUT.
  # POSIX hosts raise DTR as part of opening the port, so this is a no-op there.
  #
  # EspFlasher deliberately drives DTR/RTS itself to reset ESP32 boards into the
  # boot ROM and opens its own ports rather than going through here.
  module SerialPort
    SETRTS = 3
    SETDTR = 5

    def self.open(port, baud)
      serial = Serial.new(port, baud)
      raise_modem_lines(serial) if windows?
      serial
    end

    def self.windows?
      RbConfig::CONFIG['host_os'].match?(/mswin|mingw|cygwin/)
    end

    def self.raise_modem_lines(serial)
      handle = handle_address(serial.instance_variable_get(:@fd))
      return unless handle

      escape_comm_function.call(handle, SETDTR)
      escape_comm_function.call(handle, SETRTS)
    rescue StandardError
      # Best effort: a rubyserial that stops exposing the handle should degrade
      # to the old behaviour rather than stop the command from running.
      nil
    end

    # rubyserial hands back the Win32 handle as an FFI::Pointer, which Fiddle
    # will not accept; its raw address goes through as a void* fine.
    def self.handle_address(handle)
      return nil if handle.nil?

      address = handle.respond_to?(:address) ? handle.address : handle.to_i
      address.zero? ? nil : address
    end

    def self.escape_comm_function
      @escape_comm_function ||= begin
        require 'fiddle'
        Fiddle::Function.new(
          Fiddle.dlopen('kernel32.dll')['EscapeCommFunction'],
          [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT],
          Fiddle::TYPE_INT
        )
      end
    end
  end
end
