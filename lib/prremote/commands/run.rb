require 'open3'
require 'tempfile'
require_relative '../mrbc'

module Prremote
  module Commands
    class Run
      def initialize(port:, baud:)
        @port = port
        @baud = baud
      end

      def call(*rb_paths)
        rb_paths.each { |f| raise "File not found: #{f}" unless File.exist?(f) }

        warn "Compiling #{rb_paths.map { |f| File.basename(f) }.join(', ')}..."
        mrb_data = compile(*rb_paths)

        warn 'Running...'
        run_on_device(mrb_data)
      rescue Interrupt
        warn ''
      end

      private

      def compile(*rb_paths)
        Mrbc.check_version!
        tmp = Tempfile.new(['prremote', '.mrb'])
        out, status = Open3.capture2e(Mrbc.bin, '-o', tmp.path, *rb_paths)
        raise "mrbc failed:\n#{out.chomp}" unless status.success?

        File.binread(tmp.path)
      ensure
        tmp&.close!
      end

      def run_on_device(mrb_data)
        serial = Serial.new(@port, @baud)
        sleep 0.5
        drained = serial.read(4096) || ''
        debug "drained #{drained.bytesize} bytes: #{drained.inspect}"

        serial.write(mrb_data)
        debug "sent #{mrb_data.bytesize} bytes (first 4: #{mrb_data[0, 4].inspect})"

        post_running = wait_for_running(serial)
        stream_until_done(serial, post_running)
      rescue Interrupt
        serial&.write("\x03")
        sleep 0.1
        raise
      ensure
        serial&.close
      end

      def wait_for_running(serial)
        buf = +''
        deadline = Time.now + 10
        loop do
          chunk = normalize(serial.read(256) || '')
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
          buf << normalize(serial.read(256) || '')

          if (done_pos = buf.index("DONE\n"))
            $stdout.print buf[0, done_pos] unless done_pos.zero?
            $stdout.flush
            return
          end

          if buf.length > 512
            safe = buf.length - 5
            $stdout.print buf[0, safe]
            $stdout.flush
            buf = buf[safe..]
          end

          sleep 0.01
        end
      end

      def normalize(str)
        str.gsub("\r\n", "\n").gsub("\r", '')
      end

      def debug(msg)
        warn "[debug] #{msg}" if ENV['PRREMOTE_DEBUG']
      end
    end
  end
end
