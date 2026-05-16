require 'fileutils'

module Prremote
  module Commands
    class Install
      def initialize(version: RUNTIME_VERSION)
        @version = version
      end

      def call
        uf2_path = RuntimeManager.fetch(@version)

        puts 'Put the Pico W into BOOTSEL mode:'
        puts '  1. Hold the BOOTSEL button'
        puts '  2. Connect USB (or press RUN while holding BOOTSEL)'
        puts '  3. Release BOOTSEL — RPI-RP2 should appear as a USB drive'
        puts
        puts 'Waiting for RPI-RP2...'

        volume = wait_for_volume
        puts "Copying firmware to #{volume}..."
        FileUtils.cp(uf2_path, File.join(volume, File.basename(uf2_path)))

        puts 'Waiting for device to reboot...'
        wait_for_unmount(volume)

        puts "Done. Runtime #{@version} installed."
      end

      private

      def volume_paths
        [
          '/Volumes/RPI-RP2',
          "/run/media/#{ENV.fetch('USER', nil)}/RPI-RP2",
          "/media/#{ENV.fetch('USER', nil)}/RPI-RP2"
        ]
      end

      def wait_for_volume(timeout: 60)
        deadline = Time.now + timeout
        loop do
          path = volume_paths.find { |p| File.directory?(p) }
          return path if path
          raise "Timed out waiting for RPI-RP2 volume (#{timeout}s)" if Time.now > deadline

          sleep 1
        end
      end

      def wait_for_unmount(volume, timeout: 30)
        deadline = Time.now + timeout
        loop do
          return unless File.directory?(volume)
          raise "Timed out waiting for device to reboot (#{timeout}s)" if Time.now > deadline

          sleep 1
        end
      end
    end
  end
end
