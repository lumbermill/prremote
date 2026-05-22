require_relative 'run'

module Prremote
  module Commands
    class Watch
      POLL_INTERVAL = 0.5

      def initialize(port:, baud:)
        @port = port
        @baud = baud
      end

      def call(*rb_paths)
        rb_paths.each { |f| raise "File not found: #{f}" unless File.exist?(f) }

        label = rb_paths.map { |f| File.basename(f) }.join(', ')
        warn "Watching #{label} (Ctrl+C to stop)..."
        mtimes = rb_paths.map { |f| File.mtime(f) }
        run(*rb_paths)

        loop do
          sleep POLL_INTERVAL
          new_mtimes = rb_paths.map { |f| File.mtime(f) }
          next if new_mtimes == mtimes

          mtimes = new_mtimes
          warn "\n--- #{label} changed, re-running ---"
          run(*rb_paths)
        end
      rescue Interrupt
        warn "\nStopped watching."
      end

      private

      def run(*rb_paths)
        Run.new(port: @port, baud: @baud).call(*rb_paths)
      rescue StandardError => e
        warn "Error: #{e.message}"
      end
    end
  end
end
