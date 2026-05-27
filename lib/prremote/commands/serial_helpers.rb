module Prremote
  module Commands
    module SerialHelpers
      def wait_for_ready(serial)
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
