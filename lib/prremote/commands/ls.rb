module Prremote
  module Commands
    class Ls
      QUERY_MAGIC = 'QURY'.freeze

      def initialize(port:, baud:)
        @port = port
        @baud = baud
      end

      def call
        result = query_device
        if result
          ts_str = if result[:timestamp].positive?
                     Time.at(result[:timestamp]).strftime('%Y-%m-%d %H:%M:%S')
                   else
                     '(unknown)'
                   end
          puts 'Deployed script:'
          puts "  Files:    #{result[:names]}"
          puts "  Deployed: #{ts_str}"
        else
          puts 'No script deployed.'
        end
      end

      private

      def query_device
        serial = Serial.new(@port, @baud)
        sleep 0.5
        serial.read(4096)

        serial.write(QUERY_MAGIC)

        buf = +''
        deadline = Time.now + 5
        loop do
          chunk = normalize(serial.read(256) || '')
          buf << chunk

          if (m = buf.match(/^DEPLOYED (\d+) (.+)\n/))
            return { timestamp: m[1].to_i, names: m[2].strip }
          end
          return nil if buf.include?("NONE\n")

          if Time.now > deadline
            raise 'Timeout waiting for device response. ' \
                  'If a script is running, use `prremote reset` first.'
          end

          sleep 0.05
        end
      ensure
        serial&.close
      end

      def normalize(str)
        str.gsub("\r\n", "\n").gsub("\r", '')
      end
    end
  end
end
