require 'rubyserial'
require 'digest'
require 'rbconfig'

module Prremote
  # Pure-Ruby flasher for classic ESP32 (Xtensa) boards.
  # Speaks the Espressif serial bootloader protocol directly so
  # `install --board esp32` needs no external tools.
  #
  # For ESP32-C6 and other USB-JTAG/Serial chips the ROM does not support
  # direct flash write/erase (FLASH_BEGIN returns error 0x38 regardless of
  # parameters).  esptool uploads a RAM stub before writing; we delegate those
  # boards to the `esptool` CLI instead of reimplementing the stub protocol.
  #
  # Protocol reference:
  # https://docs.espressif.com/projects/esptool/en/latest/esp32/advanced-topics/serial-protocol.html
  class EspFlasher
    # Command opcodes
    FLASH_BEGIN    = 0x02
    FLASH_DATA     = 0x03
    FLASH_END      = 0x04
    SYNC           = 0x08
    READ_REG       = 0x0A
    SPI_SET_PARAMS = 0x0B
    SPI_ATTACH     = 0x0D
    CHANGE_BAUD    = 0x0F
    SPI_FLASH_MD5  = 0x13

    FLASH_WRITE_SIZE = 0x400 # max data per FLASH_DATA packet
    CHECKSUM_SEED    = 0xEF
    ROM_BAUD         = 115_200

    # Boards with built-in USB Serial/JTAG — flashed via esptool subprocess.
    USB_JTAG_SERIAL_BOARDS = %w[esp32c6].freeze

    # Classic ESP32 ROM only auto-attaches flash on modules with pads wired
    # to the default HSPI pins. SiP packages with in-package flash (e.g.
    # ESP32-PICO-D4, used on M5StickC/PLUS) route flash through pins burned
    # into eFuse instead, and FLASH_BEGIN silently hangs forever (no error
    # response) if SPI_ATTACH(0) is sent on those. Mirrors esptool's
    # attach_flash()/get_chip_spi_pads() (cmds.py / targets/esp32.py).
    EFUSE_RD_REG_BASE          = 0x3FF5A000
    EFUSE_BLK0_RDATA3_REG_OFFS = EFUSE_RD_REG_BASE + 0x00C
    EFUSE_BLK0_RDATA5_REG_OFFS = EFUSE_RD_REG_BASE + 0x014

    # ROM status-byte count: classic ESP32 appends 4 bytes, RISC-V chips 2.
    STATUS_BYTES_BY_BOARD = Hash.new(4).freeze

    # Classic ESP32 SPI_ATTACH takes [hspi_arg, extended_arg] (8 bytes);
    # newer RISC-V chips take only [hspi_arg] (4 bytes).
    SPI_ATTACH_LEGACY_BOARDS = %w[esp32].freeze

    MD5_HEX_LENGTH = 32
    MD5_RAW_LENGTH = 16

    # ioctl modem-control constants
    TIOCM_DTR = 0x0002
    TIOCM_RTS = 0x0004
    DARWIN    = RbConfig::CONFIG['host_os'] =~ /darwin/ ? true : false
    TIOCMGET  = DARWIN ? 0x4004746A : 0x5415
    TIOCMSET  = DARWIN ? 0x8004746D : 0x5418

    class Error < RuntimeError; end

    # Entry point.  Routes USB-JTAG/Serial boards through esptool; handles
    # classic ESP32 with the pure-Ruby protocol implementation.
    def self.flash(port:, image_path:, baud: ROM_BAUD, board: nil, verbose: false)
      if USB_JTAG_SERIAL_BOARDS.include?(board)
        return flash_via_esptool(port: port, image_path: image_path, board: board,
                                 verbose: verbose)
      end

      unless RbConfig::CONFIG['host_os'] =~ /darwin|linux/
        raise Error, 'pure-Ruby flashing supports macOS/Linux only; ' \
                     'on other systems use esptool: ' \
                     "esptool write-flash 0x0 #{image_path}"
      end

      image        = File.binread(image_path)
      status_bytes = STATUS_BYTES_BY_BOARD[board]
      serial       = Serial.new(port, ROM_BAUD)
      flasher      = new(serial, fd: serial.instance_variable_get(:@fd),
                                 status_bytes: status_bytes, board: board, verbose: verbose)
      begin
        flasher.enter_bootloader
        flasher.sync!
        upgrade = baud != ROM_BAUD && baud_supported?(baud)
        serial = flasher.upgrade_baud(port, baud) if upgrade
        flasher.write_flash(image, offset: 0)
        flasher.verify_md5(image, offset: 0)
        flasher.finish_flash
        flasher.hard_reset
      ensure
        serial.close
      end
    end

    def self.baud_supported?(baud)
      RubySerial::Posix::BAUDE_RATES.key?(baud)
    rescue NameError
      false
    end

    # Flash via the `esptool` CLI (required for USB-JTAG/Serial boards whose
    # ROM does not support direct write).  esptool handles stub upload
    # internally; we just need it installed.
    def self.flash_via_esptool(port:, image_path:, board:, verbose:)
      esptool = find_esptool
      unless esptool
        raise Error, <<~MSG.strip
          Flashing #{board} requires esptool.
          Install:  brew install esptool
              or:  pip3 install esptool
        MSG
      end

      ctx = { esptool: esptool, port: port, image_path: image_path, board: board, verbose: verbose }

      # USB-Serial/JTAG chips (e.g. XIAO ESP32C6) can be dropped into the
      # download ROM over USB, so esptool's usb-reset flashes hands-free — no
      # BOOT/RST button dance. --after hard-reset then reboots straight into the
      # freshly flashed firmware. Verified on a physical XIAO ESP32C6.
      return if esptool_write(ctx, before: 'usb-reset', after: 'hard-reset', connect_attempts: 7)

      # Fallback for hosts/boards where usb-reset doesn't take: enter the
      # bootloader by hand and let esptool retry forever. --before no-reset never
      # resets the chip, so each attempt just re-sends SYNC until the manual
      # BOOT/RST lands the board in download mode — no timeout to race against.
      warn ''
      warn "Couldn't reset #{board} automatically. Put it in bootloader mode by hand:"
      warn '  XIAO ESP32C6: hold BOOT, press RST, release both.'
      warn 'No rush — esptool keeps retrying the SYNC handshake until it connects.'
      esptool_write(ctx, before: 'no-reset', after: 'no-reset', connect_attempts: 0) or
        raise Error, 'esptool exited with an error'

      warn ''
      warn 'Flash complete. Press RST to start the firmware.'
    end

    # Runs one `esptool write-flash 0x0 <image>` pass, returning esptool's
    # success boolean.  connect_attempts 0 = retry the connect forever.
    # `ctx` carries the fixed invocation context (esptool/port/image_path/board/verbose).
    def self.esptool_write(ctx, before:, after:, connect_attempts:)
      cmd = [*ctx[:esptool],
             '--chip', ctx[:board], '--port', ctx[:port],
             '--connect-attempts', connect_attempts.to_s,
             '--before', before, '--after', after,
             'write-flash', '0x0', ctx[:image_path]]
      warn "[flash] #{cmd.join(' ')}" if ctx[:verbose]
      system(*cmd)
    end

    def self.find_esptool
      dirs = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR)
      %w[esptool esptool.py].each do |exe|
        return [exe] if dirs.any? { |d| (f = File.join(d, exe)) && File.executable?(f) && !File.directory?(f) }
      end
      # python3 -m esptool fallback: must actually import the module to verify
      return ['python3', '-m', 'esptool'] if
        system('python3', '-c', 'import esptool', out: File::NULL, err: File::NULL)

      nil
    rescue StandardError
      nil
    end

    # ── instance ──────────────────────────────────────────────────────────

    # `serial` needs #read/#write; `fd` enables DTR/RTS control.
    def initialize(serial, fd: nil, status_bytes: 4, board: nil, verbose: false)
      @serial       = serial
      @fd           = fd
      @rxbuf        = +''.b
      @status_bytes = status_bytes
      @board        = board.to_s
      @verbose      = verbose
    end

    # Classic auto-reset: RTS→EN, DTR→IO0 (via external UART bridge).
    def enter_bootloader
      set_lines(dtr: false, rts: true)
      sleep 0.1
      set_lines(dtr: true, rts: false)
      sleep 0.05
      set_lines(dtr: false, rts: false)
    end

    def hard_reset
      set_lines(dtr: false, rts: true)
      sleep 0.1
      set_lines(dtr: false, rts: false)
    end

    # ── protocol steps ─────────────────────────────────────────────────────

    def sync!
      payload = [0x07, 0x07, 0x12, 0x20].pack('C4') + ([0x55] * 32).pack('C32')
      synced = 8.times.any? do |i|
        @rxbuf.clear
        begin
          vlog format('sync: attempt %<n>d/8 (status_bytes=%<sb>d)', n: i + 1, sb: @status_bytes)
          command(SYNC, payload, timeout: 0.5)
          drain_responses
          vlog 'sync: success'
          true
        rescue Error => e
          vlog format('sync: attempt %<n>d failed (%<msg>s)', n: i + 1, msg: e.message)
          false
        end
      end
      raise Error, 'could not sync with the ESP boot ROM' unless synced
    end

    # CHANGE_BAUDRATE, then reopen the port at the new speed.
    def upgrade_baud(port, baud)
      command(CHANGE_BAUD, [baud, 0].pack('V2'))
      @serial.close
      sleep 0.05
      serial  = Serial.new(port, baud)
      @serial = serial
      @fd     = serial.instance_variable_get(:@fd)
      @rxbuf.clear
      serial
    end

    def write_flash(image, offset: 0)
      hspi_arg = SPI_ATTACH_LEGACY_BOARDS.include?(@board) ? efuse_spi_attach_arg : 0
      spi_attach_payload = SPI_ATTACH_LEGACY_BOARDS.include?(@board) ? [hspi_arg, 0].pack('V2') : [hspi_arg].pack('V')
      command(SPI_ATTACH, spi_attach_payload)
      # id, total_size, block_size, sector_size, page_size, status_mask
      command(SPI_SET_PARAMS, [0, 4 * 1024 * 1024, 64 * 1024, 4096, 256, 0xFFFF].pack('V6'))

      blocks        = (image.bytesize + FLASH_WRITE_SIZE - 1) / FLASH_WRITE_SIZE
      erase_size    = blocks * FLASH_WRITE_SIZE
      erase_timeout = 30 * (1 + (erase_size / (1024 * 1024)))
      command(FLASH_BEGIN, [erase_size, blocks, FLASH_WRITE_SIZE, offset].pack('V4'),
              timeout: erase_timeout)
      stream_blocks(image, blocks)
    end

    # FLASH_END is a courtesy; hard_reset resets the chip anyway.
    # The ROM has been seen returning error 0x06 here — ignore it.
    def finish_flash
      command(FLASH_END, [1].pack('V'))
    rescue Error
      nil
    end

    def verify_md5(image, offset: 0)
      timeout    = 8 * (1 + (image.bytesize / (1024 * 1024)))
      _v, data   = command(SPI_FLASH_MD5, [offset, image.bytesize, 0, 0].pack('V4'),
                           timeout: timeout)
      # Classic ESP32 ROM returns 32 hex ASCII chars; detect by length.
      device_md5 = data.bytesize >= MD5_HEX_LENGTH ? data[0, MD5_HEX_LENGTH] : data[0, MD5_RAW_LENGTH].unpack1('H*')
      local_md5  = Digest::MD5.hexdigest(image)
      return if device_md5 == local_md5

      raise Error, "MD5 mismatch after flashing (device #{device_md5}, local #{local_md5})"
    end

    # SPI_ATTACH(0) only works for modules with flash on the default HSPI
    # pins. In-package flash (ESP32-PICO-D4/V3, e.g. M5StickC/PLUS) needs its
    # actual pin numbers, burned into eFuse, packed into SPI_ATTACH's arg.
    # Returns 0 (the "use default pins" value) when eFuse has nothing burned.
    def efuse_spi_attach_arg
      rdata5 = read_reg(EFUSE_BLK0_RDATA5_REG_OFFS)
      clk    = rdata5 & 0x1F
      q      = (rdata5 >> 5) & 0x1F
      d      = (rdata5 >> 10) & 0x1F
      cs     = (rdata5 >> 15) & 0x1F
      hd     = (read_reg(EFUSE_BLK0_RDATA3_REG_OFFS) >> 4) & 0x1F

      return 0 if [clk, q, d, hd, cs].all?(&:zero?)

      vlog format('in-package flash detected (CLK:%<clk>d Q:%<q>d D:%<d>d HD:%<hd>d CS:%<cs>d)',
                  clk: clk, q: q, d: d, hd: hd, cs: cs)
      (hd << 24) | (cs << 18) | (d << 12) | (q << 6) | clk
    end

    def read_reg(addr)
      value, = command(READ_REG, [addr].pack('V'))
      value
    end

    # ── request/response plumbing ──────────────────────────────────────────

    def command(op, payload, checksum: 0, timeout: 3)
      packet = [0x00, op, payload.bytesize].pack('CCv') +
               [checksum].pack('V') + payload
      @serial.write(slip_encode(packet))

      deadline = Time.now + timeout
      loop do
        frame = read_frame(deadline)
        raise Error, format('timeout waiting for response to 0x%<op>02x', op: op) if frame.nil?

        result = parse_response(frame, op)
        return result if result
      end
    end

    def checksum(data)
      data.bytes.reduce(CHECKSUM_SEED) { |acc, b| acc ^ b }
    end

    def slip_encode(packet)
      escaped = packet.gsub("\xDB".b, "\xDB\xDD".b).gsub("\xC0".b, "\xDB\xDC".b)
      "\xC0".b + escaped + "\xC0".b
    end

    def slip_decode(frame)
      frame.gsub("\xDB\xDC".b, "\xC0".b).gsub("\xDB\xDD".b, "\xDB".b)
    end

    private

    def vlog(msg)
      warn "[flash] #{msg}" if @verbose
    end

    def stream_blocks(image, blocks)
      blocks.times do |seq|
        block = image.byteslice(seq * FLASH_WRITE_SIZE, FLASH_WRITE_SIZE)
        block += "\xFF".b * (FLASH_WRITE_SIZE - block.bytesize)
        command(FLASH_DATA,
                [block.bytesize, seq, 0, 0].pack('V4') + block,
                checksum: checksum(block), timeout: 5)
        progress(seq + 1, blocks)
      end
      $stderr.print "\n"
    end

    def parse_response(frame, op)
      return nil if frame.bytesize < 8 + @status_bytes || frame.getbyte(0) != 0x01 ||
                    frame.getbyte(1) != op

      value  = frame.byteslice(4, 4).unpack1('V')
      body   = frame.byteslice(8..)
      status = body.byteslice(-@status_bytes, @status_bytes)
      if status.getbyte(0) != 0
        raise Error, format('command 0x%<op>02x failed (error 0x%<err>02x)',
                            op: op, err: status.getbyte(1))
      end

      [value, body.byteslice(0...-@status_bytes)]
    end

    def read_frame(deadline)
      loop do
        start = @rxbuf.index("\xC0".b)
        if start
          stop = @rxbuf.index("\xC0".b, start + 1)
          if stop
            frame = @rxbuf.byteslice((start + 1)...stop)
            @rxbuf = @rxbuf.byteslice((stop + 1)..) || +''.b
            next if frame.empty?

            return slip_decode(frame)
          end
        end
        return nil if Time.now > deadline

        chunk = @serial.read(256) || ''
        chunk.empty? ? sleep(0.01) : @rxbuf << chunk.b
      end
    end

    def drain_responses
      deadline = Time.now + 0.3
      loop { break if read_frame(deadline).nil? }
    end

    # Sets DTR and RTS together via a single TIOCMSET, matching esptool's
    # UnixTightReset. Two separate TIOCMBIS/TIOCMBIC calls (the classic-reset
    # approach) send DTR and RTS as separate USB control-line-state requests;
    # some USB-serial adapters (seen with CP2104 on M5StickC PLUS) glitch the
    # boot ROM's auto-reset during that gap.
    def set_lines(dtr:, rts:)
      return if @fd.nil?

      io  = IO.for_fd(@fd, autoclose: false)
      buf = [0].pack('L')
      io.ioctl(TIOCMGET, buf)
      status = buf.unpack1('L')
      status = dtr ? (status | TIOCM_DTR) : (status & ~TIOCM_DTR)
      status = rts ? (status | TIOCM_RTS) : (status & ~TIOCM_RTS)
      io.ioctl(TIOCMSET, [status].pack('L'))
    rescue StandardError
      nil
    end

    def progress(done, total)
      pct = done * 100 / total
      return if pct == @last_pct

      @last_pct = pct
      $stderr.print format("\rWriting %<pct>3d%% (%<done>d/%<total>d)",
                           pct: pct, done: done, total: total)
    end
  end
end
