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
        serial.write("\x03")

        # \x03 may trigger a watchdog reboot (if a script was running).
        # wait_for_ready returns the active serial (original or reopened).
        serial = wait_for_ready(serial)

        serial.write(ERASE_MAGIC)
        wait_for_erased(serial)
        warn 'Flash erased. Device will no longer auto-run a script on boot.'
      ensure
        serial&.close rescue nil
      end

      private

      # Returns the serial object in READY state (may be a new object after reboot).
      def wait_for_ready(serial)
        buf      = +''
        deadline = Time.now + 10
        loop do
          begin
            buf << (serial.read(256) || '').gsub("\r\n", "\n").gsub("\r", '')
          rescue StandardError
            # Watchdog reboot dropped USB; wait for device to re-enumerate.
            serial.close rescue nil
            serial = nil
            reopen_deadline = [deadline, Time.now + 8].min
            loop do
              raise 'Timeout waiting for device to reconnect' if Time.now > reopen_deadline

              candidate = Detector.find_device || @port
              if candidate && File.exist?(candidate)
                begin
                  serial = Serial.new(candidate, @baud)
                  @port  = candidate
                  break
                rescue StandardError
                  nil
                end
              end
              sleep 0.3
            end
            buf = +''
            next
          end

          return serial if buf.include?('READY prremote-runtime/')
          raise 'Timeout waiting for READY' if Time.now > deadline

          sleep 0.05
        end
      end

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
