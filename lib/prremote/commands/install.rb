require 'fileutils'
require_relative '../boards'
require_relative 'serial_helpers'

module Prremote
  module Commands
    class Install
      include SerialHelpers

      BOARD_MAGIC = 'BORD'.freeze

      DEVICE_LABELS = { 'pico' => 'Pico', 'picow' => 'Pico W', 'pico2' => 'Pico 2' }.freeze

      # The UF2 bootloader exposes this file on the BOOTSEL volume.
      BOOTSEL_MARKER = 'INFO_UF2.TXT'.freeze

      # Boards whose install path has not been run on real hardware yet.
      UNVERIFIED_BOARDS = %w[pico2].freeze

      # board may be a runtime image name (esp32) or a board sharing one
      # (m5stickc_plus → esp32 image); see Boards::FIRMWARE.
      def initialize(version: VERSION, board: 'picow', port: nil, verbose: false)
        @version  = version
        @board    = board
        @firmware = Boards.firmware_for(board)
        @port     = port
        @verbose  = verbose
      end

      # Runtime images plus boards that share one (m5stickc_plus).
      def self.board_names
        RuntimeManager::BOARDS + Boards.names
      end

      def call
        return install_esp32 if RuntimeManager::ESP32_BOARDS.include?(@firmware)

        uf2_path = RuntimeManager.fetch(@version, @board)

        warn_unverified
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
        image = RuntimeManager.fetch(@version, @firmware)
        port  = @port || Detector.find_device
        unless port
          message = 'No serial device found. Connect the board or pass --port.'
          hint    = Detector.no_device_hint
          raise [message, hint].compact.join("\n")
        end

        puts "Flashing #{File.basename(image)} to #{port}..."
        EspFlasher.flash(port: port, image_path: image, board: @firmware, verbose: @verbose)
        record_board(port)
        puts "Done. Runtime #{@version} installed."
      end

      # One ESP32 image serves several boards, so tell the runtime which one
      # this is (kept in NVS; reported as board= in READY, which picks the
      # board libraries). Installing the plain image clears it.
      def record_board(port)
        name = @board == @firmware ? '' : @board
        serial = Serial.new(port, 115_200)
        wait_for_ready(serial)
        serial.write(BOARD_MAGIC + [name.bytesize].pack('C') + name)
        reply = wait_for_board_reply(serial)
        if reply.nil?
          warn "WARNING: runtime #{@version} does not record board names; board=#{@board} not set."
        elsif !name.empty?
          puts "Board: #{reply}"
        end
      ensure
        serial&.close
      end

      # "BOARD <name>" on success; nil if the runtime predates the command.
      def wait_for_board_reply(serial)
        buf = +''
        deadline = Time.now + 3
        loop do
          buf << normalize(safe_read(serial, 256))
          return Regexp.last_match(1) if buf =~ /^BOARD (\S+)\n/
          raise "Device rejected board name '#{@board}'" if buf.include?("ERROR board\n")
          return nil if Time.now > deadline

          sleep 0.05
        end
      end

      def warn_unverified
        return unless UNVERIFIED_BOARDS.include?(@board)

        warn "NOTE: installing on #{device_label} has not been verified on real hardware yet."
        warn '      Please report the result at https://github.com/lumbermill/prremote/issues'
      end

      def device_label
        DEVICE_LABELS.fetch(@board, 'Pico')
      end

      # The RP2040 boot ROM mounts its BOOTSEL drive as RPI-RP2; the RP2350
      # (Pico 2) boot ROM uses RP2350 instead. INFO_UF2.TXT carries the same
      # name as its Board-ID.
      def volume_name
        @board == 'pico2' ? 'RP2350' : 'RPI-RP2'
      end

      def volume_paths
        user = ENV.fetch('USER', nil)
        [
          "/Volumes/#{volume_name}",
          "/run/media/#{user}/#{volume_name}",
          "/media/#{user}/#{volume_name}"
        ] + drive_letter_volume_paths
      end

      # WSL reaches the Windows drive letter the BOOTSEL volume lands on through
      # drvfs at /mnt/<letter>. That path carries no volume name, so the
      # marker file is what identifies the board.
      def drive_letter_volume_paths
        drive_letter_roots.select { |root| bootsel_volume?(root) }
      end

      # /mnt/c is the Windows system drive; the board never lands there, so the
      # scan starts at D.
      def drive_letter_roots
        ('d'..'z').map { |letter| "/mnt/#{letter}" }
      end

      # Other UF2 bootloaders (and the other RP2 chip) expose INFO_UF2.TXT
      # too, so the Board-ID line is what tells the target chip apart.
      def bootsel_volume?(root)
        marker = File.join(root, BOOTSEL_MARKER)
        File.file?(marker) && /^Board-ID:\s*#{Regexp.escape(volume_name)}\s*$/.match?(File.read(marker))
      rescue SystemCallError
        false
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
