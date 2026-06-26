module Prremote
  module Commands
    module SerialHelpers
      def wait_for_ready(serial)
        # On macOS, USB CDC TX buffers can be dropped when the host reopens the port,
        # leaving the device stuck in getchar() without re-sending READY.
        # Sending Ctrl+C forces the device to restart its READY loop.
        # Resent every second: ESP32 boards reset when the port opens (DTR/RTS
        # auto-reset circuit) and a Ctrl+C sent while they are still booting
        # is lost. Harmless on Pico — 0x03 while idle just re-prints READY.
        sleep 0.1
        serial.write("\x03") rescue nil

        buf = +''
        deadline  = Time.now + 10
        next_ctrl = Time.now + 1
        loop do
          buf << normalize(safe_read(serial, 256))
          if buf.include?('READY ')
            warn_if_runtime_outdated(buf)
            return
          end
          raise 'Timeout waiting for device. Run `prremote reset` if a script is running.' if Time.now > deadline

          if Time.now > next_ctrl
            serial.write("\x03") rescue nil
            next_ctrl = Time.now + 1
          end
          sleep 0.05
        end
      end

      def normalize(str)
        str.gsub("\r\n", "\n").gsub("\r", '')
      end

      # ESP32-C6's native USB Serial/JTAG drops bytes when a large payload is
      # written in a single burst: its 256-byte driver RX ring buffer overflows
      # faster than the firmware drains it byte-by-byte, and the controller does
      # not apply USB backpressure. Writing in <=256-byte chunks with a short
      # gap keeps the device from overrunning. The pacing is negligible on the
      # baud-limited transports (Pico USB-CDC / ESP32 UART bridge), where a
      # 256-byte chunk already takes ~22 ms to clock out at 115200 baud.
      SERIAL_CHUNK_SIZE  = 256
      SERIAL_CHUNK_DELAY = 0.004

      def write_chunked(serial, data)
        i = 0
        while i < data.bytesize
          serial.write(data.byteslice(i, SERIAL_CHUNK_SIZE))
          i += SERIAL_CHUNK_SIZE
          sleep SERIAL_CHUNK_DELAY if i < data.bytesize
        end
      end

      # Wraps serial.read so that a device disconnect (e.g. ENXIO on macOS when
      # the Pico resets) surfaces as a human-readable error instead of a bare errno name.
      def safe_read(serial, size)
        serial.read(size) || ''
      rescue RubySerial::Error => e
        raise "Device disconnected (#{e.message}). Run `prremote reset` if the device is unresponsive."
      end

      private

      def warn_if_runtime_outdated(buf)
        m = buf.match(/READY prremote-runtime\/(\S+)/)
        return unless m

        runtime_ver = Gem::Version.new(m[1])
        gem_ver     = Gem::Version.new(Prremote::VERSION)
        return unless runtime_ver < gem_ver

        warn "WARNING: runtime version #{m[1]} is older than prremote #{Prremote::VERSION}. Run `prremote install` to update."
      rescue ArgumentError
        # ignore unparseable version strings
      end
    end
  end
end
