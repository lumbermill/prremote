require 'fileutils'
require_relative '../boards'
require_relative 'serial_helpers'

module Prremote
  module Commands
    class Install
      include SerialHelpers

      BOARD_MAGIC = 'BORD'.freeze

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
        image = RuntimeManager.fetch(@version, @firmware)
        port  = @port || Detector.find_device
        raise 'No serial device found. Connect the board or pass --port.' unless port

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
