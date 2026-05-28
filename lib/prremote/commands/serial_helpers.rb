module Prremote
  module Commands
    module SerialHelpers
      def wait_for_ready(serial)
        # On macOS, USB CDC TX buffers can be dropped when the host reopens the port,
        # leaving the device stuck in getchar() without re-sending READY.
        # Sending Ctrl+C forces the device to restart its READY loop.
        sleep 0.1
        serial.write("\x03") rescue nil

        buf = +''
        deadline = Time.now + 10
        loop do
          buf << normalize(serial.read(256) || '')
          return if buf.include?('READY ')
          raise 'Timeout waiting for device. Run `prremote reset` if a script is running.' if Time.now > deadline

          sleep 0.05
        end
      end

      def normalize(str)
        str.gsub("\r\n", "\n").gsub("\r", '')
      end
    end
  end
end
