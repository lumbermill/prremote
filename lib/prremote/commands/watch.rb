require_relative 'run'

module Prremote
  module Commands
    class Watch
      POLL_INTERVAL = 0.5

      def initialize(port:, baud:)
        @port = port
        @baud = baud
      end

      def call(rb_path)
        raise "File not found: #{rb_path}" unless File.exist?(rb_path)

        warn "Watching #{rb_path} (Ctrl+C to stop)..."
        last_mtime = File.mtime(rb_path)
        run(rb_path)

        loop do
          sleep POLL_INTERVAL
          mtime = File.mtime(rb_path)
          next if mtime == last_mtime

          last_mtime = mtime
          warn "\n--- #{rb_path} changed, re-running ---"
          run(rb_path)
        end
      rescue Interrupt
        warn "\nStopped watching."
      end

      private

      def run(rb_path)
        Run.new(port: @port, baud: @baud).call(rb_path)
      rescue StandardError => e
        warn "Error: #{e.message}"
      end
    end
  end
end
