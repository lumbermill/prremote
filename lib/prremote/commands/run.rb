require "open3"
require "tempfile"

module Prremote
  module Commands
    class Run
      def initialize(port:, baud:)
        @port = port
        @baud = baud
      end

      def call(rb_path)
        raise "File not found: #{rb_path}" unless File.exist?(rb_path)

        warn "Compiling #{rb_path}..."
        mrb_data = compile(rb_path)

        warn "Running..."
        run_on_device(mrb_data)
      end

      private

      def compile(rb_path)
        tmp = Tempfile.new(["prremote", ".mrb"])
        out, status = Open3.capture2e(mrbc_bin, "-o", tmp.path, rb_path)
        raise "mrbc failed:\n#{out.chomp}" unless status.success?

        File.binread(tmp.path)
      ensure
        tmp&.close!
      end

      def mrbc_bin
        return ENV["MRBC"] if ENV["MRBC"] && File.executable?(ENV["MRBC"])

        found = ENV["PATH"].split(File::PATH_SEPARATOR)
                           .reject { |d| d.match?(%r{\.rbenv/shims}) }
                           .map { |d| File.join(d, "mrbc") }
                           .find { |f| File.executable?(f) }

        found || raise("mrbc not found. Install mruby: brew install mruby")
      end

      def run_on_device(mrb_data)
        serial = Serial.new(@port, @baud)
        sleep 0.5
        drained = serial.read(4096) || ""
        debug "drained #{drained.bytesize} bytes: #{drained.inspect}"

        serial.write(mrb_data)
        debug "sent #{mrb_data.bytesize} bytes (first 4: #{mrb_data[0, 4].inspect})"

        post_running = wait_for_running(serial)
        stream_until_done(serial, post_running)
      ensure
        serial&.close
      end

      def wait_for_running(serial)
        buf = +""
        deadline = Time.now + 10
        loop do
          chunk = normalize(serial.read(256) || "")
          unless chunk.empty?
            debug "recv: #{chunk.inspect}"
            buf << chunk
          end
          raise "Device error: #{buf.strip}" if buf.match?(/^ERROR /)

          if (idx = buf.index("RUNNING\n"))
            return buf[(idx + "RUNNING\n".length)..]
          end

          raise "Timeout waiting for device to start execution" if Time.now > deadline

          sleep 0.05
        end
      end

      def stream_until_done(serial, initial = +"")
        buf = initial
        loop do
          buf << normalize(serial.read(256) || "")

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
        str.gsub("\r\n", "\n").gsub("\r", "")
      end

      def debug(msg)
        warn "[debug] #{msg}" if ENV["PRREMOTE_DEBUG"]
      end
    end
  end
end
