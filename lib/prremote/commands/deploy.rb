require 'open3'
require 'tempfile'
require_relative '../mrbc'

module Prremote
  module Commands
    class Deploy
      DEPLOY_MAGIC = 'DPLY'.freeze

      def initialize(port:, baud:)
        @port = port
        @baud = baud
      end

      def call(*rb_paths)
        rb_paths.each { |f| raise "File not found: #{f}" unless File.exist?(f) }

        warn "Compiling #{rb_paths.map { |f| File.basename(f) }.join(', ')}..."
        mrb_data = compile(*rb_paths)

        warn 'Deploying to flash...'
        deploy_to_device(mrb_data)
        warn 'Deployed. Script will run automatically on next boot.'
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

      def deploy_to_device(mrb_data)
        serial = Serial.new(@port, @baud)
        sleep 0.5
        serial.read(4096)

        serial.write(DEPLOY_MAGIC + mrb_data)
        debug "sent DPLY + #{mrb_data.bytesize} bytes"

        wait_for_deployed(serial)
      ensure
        serial&.close
      end

      def wait_for_deployed(serial)
        buf = +''
        deadline = Time.now + 30
        loop do
          chunk = normalize(serial.read(256) || '')
          buf << chunk unless chunk.empty?

          return if buf.include?("DEPLOYED\n")
          raise "Device error: #{buf.strip}" if buf.match?(/^ERROR /)
          raise 'Timeout waiting for deploy confirmation' if Time.now > deadline

          sleep 0.05
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
