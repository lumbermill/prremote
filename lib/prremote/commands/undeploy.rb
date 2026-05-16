module Prremote
  module Commands
    class Undeploy
      ERASE_MAGIC = 'ERSE'.freeze

      def initialize(port:, baud:)
        @port = port
        @baud = baud
      end

      def call
        serial = Serial.new(@port, @baud)
        sleep 0.5
        serial.read(4096)

        serial.write(ERASE_MAGIC)
        wait_for_erased(serial)
        warn 'Flash erased. Device will no longer auto-run a script on boot.'
      ensure
        serial&.close
      end

      private

      def wait_for_erased(serial)
        buf = +''
        deadline = Time.now + 30
        loop do
          chunk = (serial.read(256) || '').gsub("\r\n", "\n").gsub("\r", '')
          buf << chunk unless chunk.empty?

          return if buf.include?("ERASED\n")
          raise "Device error: #{buf.strip}" if buf.match?(/^ERROR /)
          raise 'Timeout waiting for erase confirmation' if Time.now > deadline

          sleep 0.05
        end
      end
    end
  end
end
