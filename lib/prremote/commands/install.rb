require 'fileutils'

module Prremote
  module Commands
    class Install
      # The RP2 bootloader always exposes this file on the BOOTSEL volume.
      BOOTSEL_MARKER = 'INFO_UF2.TXT'.freeze

      def initialize(version: VERSION, board: 'picow', port: nil, verbose: false)
        @version = version
        @board   = board
        @port    = port
        @verbose = verbose
      end

      def call
        return install_esp32 if RuntimeManager::ESP32_BOARDS.include?(@board)

        uf2_path = RuntimeManager.fetch(@version, @board)

        device_label = @board == 'picow' ? 'Pico W' : 'Pico'
        puts "Put the #{device_label} into BOOTSEL mode:"
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

      # No BOOTSEL dance on ESP32: the flasher toggles DTR/RTS to enter the
      # boot ROM by itself, so flashing works over the normal serial port.
      def install_esp32
        image = RuntimeManager.fetch(@version, @board)
        port  = @port || Detector.find_device
        unless port
          message = 'No serial device found. Connect the board or pass --port.'
          hint    = Detector.no_device_hint
          raise [message, hint].compact.join("\n")
        end

        puts "Flashing #{File.basename(image)} to #{port}..."
        EspFlasher.flash(port: port, image_path: image, board: @board, verbose: @verbose)
        puts "Done. Runtime #{@version} installed."
      end

      def volume_paths
        [
          '/Volumes/RPI-RP2',
          "/run/media/#{ENV.fetch('USER', nil)}/RPI-RP2",
          "/media/#{ENV.fetch('USER', nil)}/RPI-RP2"
        ] + drive_letter_volume_paths
      end

      # Windows mounts the BOOTSEL volume on a drive letter, and WSL reaches the
      # same drive through drvfs at /mnt/<letter>. Neither path carries the
      # RPI-RP2 volume name, so the marker file is what identifies the board.
      def drive_letter_volume_paths
        drive_letter_roots.select { |root| File.file?(File.join(root, BOOTSEL_MARKER)) }
      end

      # C: is the system drive on Windows and the Windows filesystem under WSL;
      # the board never lands there, so the scan starts at D.
      def drive_letter_roots
        ('d'..'z').flat_map { |letter| ["#{letter.upcase}:/", "/mnt/#{letter}"] }
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

      # The board reboots as soon as the UF2 lands, which tears the volume down.
      # Testing the marker rather than the directory covers the WSL case, where
      # the /mnt/<letter> mountpoint outlives the drive it pointed at.
      def wait_for_unmount(volume, timeout: 30)
        deadline = Time.now + timeout
        loop do
          return unless mounted?(volume)
          raise "Timed out waiting for device to reboot (#{timeout}s)" if Time.now > deadline

          sleep 1
        end
      end

      def mounted?(volume)
        File.directory?(volume) && File.file?(File.join(volume, BOOTSEL_MARKER))
      rescue SystemCallError
        # A stale drvfs mountpoint raises instead of reporting the drive as gone.
        false
      end
    end
  end
end
