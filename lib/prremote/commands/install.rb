require 'fileutils'

module Prremote
  module Commands
    class Install
      DEVICE_LABELS = { 'pico' => 'Pico', 'picow' => 'Pico W', 'pico2' => 'Pico 2' }.freeze

      def initialize(version: VERSION, board: 'picow', port: nil, verbose: false)
        @version = version
        @board   = board
        @port    = port
        @verbose = verbose
      end

      def call
        return install_esp32 if RuntimeManager::ESP32_BOARDS.include?(@board)

        uf2_path = RuntimeManager.fetch(@version, @board)

        puts "Put the #{device_label} into BOOTSEL mode:"
        puts '  1. Hold the BOOTSEL button'
        puts '  2. Connect USB (or press RUN while holding BOOTSEL)'
        puts "  3. Release BOOTSEL — #{volume_name} should appear as a USB drive"
        puts
        puts "Waiting for #{volume_name}..."

        volume = wait_for_volume
        puts "Copying firmware to #{volume}..."
        FileUtils.cp(uf2_path, File.join(volume, File.basename(uf2_path)))

        puts 'Waiting for device to reboot...'
        wait_for_unmount(volume)

        puts "Done. Runtime #{@version} installed."
      end

      private

      # No BOOTSEL dance on ESP32: the flasher toggles DTR/RTS to enter the
      # boot ROM by itself, so flashing works over the normal serial port.
      def install_esp32
        image = RuntimeManager.fetch(@version, @board)
        port  = @port || Detector.find_device
        raise 'No serial device found. Connect the board or pass --port.' unless port

        puts "Flashing #{File.basename(image)} to #{port}..."
        EspFlasher.flash(port: port, image_path: image, board: @board, verbose: @verbose)
        puts "Done. Runtime #{@version} installed."
      end

      def device_label
        DEVICE_LABELS.fetch(@board, 'Pico')
      end

      # The RP2040 boot ROM mounts its BOOTSEL drive as RPI-RP2; the RP2350
      # (Pico 2) boot ROM uses RP2350 instead.
      def volume_name
        @board == 'pico2' ? 'RP2350' : 'RPI-RP2'
      end

      def volume_paths
        user = ENV.fetch('USER', nil)
        [
          "/Volumes/#{volume_name}",
          "/run/media/#{user}/#{volume_name}",
          "/media/#{user}/#{volume_name}"
        ]
      end

      def wait_for_volume(timeout: 60)
        deadline = Time.now + timeout
        loop do
          path = volume_paths.find { |p| File.directory?(p) }
          return path if path
          raise "Timed out waiting for #{volume_name} volume (#{timeout}s)" if Time.now > deadline

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
