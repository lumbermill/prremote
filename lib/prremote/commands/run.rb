require_relative 'serial_helpers'

module Prremote
  module Commands
    class Run
      include SerialHelpers

      def initialize(port:, baud:)
        @port = port
        @baud = baud
      end

      def call(*rb_paths)
        rb_paths.each { |f| raise "File not found: #{f}" unless File.exist?(f) }

        warn "Compiling #{rb_paths.map { |f| File.basename(f) }.join(', ')}..."
        mrb_data = compile_with_boards(rb_paths)

        run_on_device(mrb_data, rb_paths)
      rescue Interrupt
        warn ''
      end

      private

      def run_on_device(mrb_data, rb_paths)
        serial = Serial.new(@port, @baud)
        check_board!(wait_for_ready(serial), rb_paths)

        warn 'Running...'
        write_chunked(serial, mrb_data)
        debug "sent #{mrb_data.bytesize} bytes (first 4: #{mrb_data[0, 4].inspect})"

        post_running = wait_for_running(serial)
        stream_until_done(serial, post_running)
      rescue Interrupt
        serial&.write("\x03") rescue nil
        sleep 0.1
        raise
      ensure
        serial&.close
      end

      def wait_for_running(serial)
        buf = +''
        deadline = Time.now + 10
        loop do
          chunk = normalize(safe_read(serial, 256))
          unless chunk.empty?
            debug "recv: #{chunk.inspect}"
            buf << chunk
          end
          raise "Device error: #{buf.strip}" if buf.match?(/^ERROR /)

          if (idx = buf.index("RUNNING\n"))
            return buf[(idx + "RUNNING\n".length)..]
          end

          raise 'Timeout waiting for device to start execution' if Time.now > deadline

          sleep 0.05
        end
      end

      def stream_until_done(serial, initial = +'')
        buf = initial
        loop do
          buf << normalize(safe_read(serial, 256))

          if (done_pos = buf.index("DONE\n"))
            $stdout.print buf[0, done_pos] unless done_pos.zero?
            $stdout.flush
            return
          end

          # Flush on newline boundaries so each puts line appears immediately.
          if (nl_pos = buf.rindex("\n"))
            $stdout.print buf[0, nl_pos + 1]
            $stdout.flush
            buf = buf[(nl_pos + 1)..]
          end

          sleep 0.01
        end
      end

      def debug(msg)
        warn "[debug] #{msg}" if ENV['PRREMOTE_DEBUG']
      end
    end
  end
end
