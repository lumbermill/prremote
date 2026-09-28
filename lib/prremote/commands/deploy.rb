require_relative 'serial_helpers'

module Prremote
  module Commands
    class Deploy
      include SerialHelpers

      DEPLOY_MAGIC = 'DPLY'.freeze
      META_MAGIC   = 'META'.freeze

      def initialize(port:, baud:)
        @port = port
        @baud = baud
      end

      def call(*rb_paths)
        rb_paths.each { |f| raise "File not found: #{f}" unless File.exist?(f) }

        deploy_to_device(rb_paths)
        warn 'Deployed. Script will run automatically on next boot.'
      end

      private

      # Connects before compiling so the board libraries match the device
      # (see Run#run_on_device).
      def deploy_to_device(rb_paths)
        serial = Serial.new(@port, @baud)
        ready = wait_for_ready(serial)

        warn "Compiling #{rb_paths.map { |f| File.basename(f) }.join(', ')}..."
        mrb_data = compile_for(ready, rb_paths)

        warn 'Deploying to flash...'
        write_chunked(serial, DEPLOY_MAGIC + build_meta_packet(rb_paths) + mrb_data)
        wait_for_deployed(serial)
      ensure
        serial&.close
      end

      def build_meta_packet(rb_paths)
        names_bytes = rb_paths.map { |f| File.basename(f) }.join(' ').encode('UTF-8').b
        name_len    = [names_bytes.bytesize, 240].min
        ts          = Time.now.to_i
        debug "meta: #{name_len} bytes, ts=#{ts}"
        META_MAGIC + [name_len].pack('C') + names_bytes[0, name_len] + [ts].pack('N')
      end

      def wait_for_deployed(serial)
        buf = +''
        deadline = Time.now + 30
        loop do
          chunk = normalize(safe_read(serial, 256))
          buf << chunk unless chunk.empty?

          return if buf.include?("DEPLOYED\n")
          raise "Device error: #{buf.strip}" if buf.match?(/^ERROR /)
          raise 'Timeout waiting for deploy confirmation' if Time.now > deadline

          sleep 0.05
        end
      end

      def debug(msg)
        warn "[debug] #{msg}" if ENV['PRREMOTE_DEBUG']
      end
    end
  end
end
