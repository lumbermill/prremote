require 'rubyserial'
require 'digest'
require 'rbconfig'

module Prremote
  # Pure-Ruby ESP32 flasher — speaks the Espressif serial bootloader protocol
  # directly so `install --board esp32` needs no esptool / Python.
  #
  # Talks to the ESP32 (classic) ROM loader only (no stub upload): SYNC,
  # SPI_ATTACH, SPI_SET_PARAMS, CHANGE_BAUDRATE, FLASH_BEGIN/DATA/END and
  # SPI_FLASH_MD5 — enough to write a merged image at offset 0x0 and verify it.
  # Protocol reference:
  # https://docs.espressif.com/projects/esptool/en/latest/esp32/advanced-topics/serial-protocol.html
  #
  # The chip is put into (and out of) the boot ROM by toggling DTR/RTS through
  # the USB-UART bridge's auto-reset circuit, via ioctl on the serial fd —
  # macOS and Linux only.
  class EspFlasher
    # Command opcodes (ROM loader subset)
    FLASH_BEGIN    = 0x02
    FLASH_DATA     = 0x03
    FLASH_END      = 0x04
    SYNC           = 0x08
    SPI_SET_PARAMS = 0x0B
    SPI_ATTACH     = 0x0D
    CHANGE_BAUD    = 0x0F
    SPI_FLASH_MD5  = 0x13

    FLASH_WRITE_SIZE = 0x400 # ROM loader max data per FLASH_DATA packet
    STATUS_BYTES     = 4     # ESP32 ROM appends 4 status bytes to responses
    CHECKSUM_SEED    = 0xEF

    ROM_BAUD = 115_200

    # ioctl modem-control constants
    TIOCM_DTR = 0x0002
    TIOCM_RTS = 0x0004
    DARWIN    = RbConfig::CONFIG['host_os'] =~ /darwin/ ? true : false
    TIOCMGET  = DARWIN ? 0x4004746A : 0x5415
    TIOCMSET  = DARWIN ? 0x8004746D : 0x5418

    class Error < RuntimeError; end

    # Flashes `image_path` at offset 0x0 and verifies it with an on-chip MD5.
    # The transfer runs at `baud` when rubyserial supports it locally
    # (macOS termios caps out at 230400), otherwise at the ROM's 115200.
    def self.flash(port:, image_path:, baud: 230_400)
      unless RbConfig::CONFIG['host_os'] =~ /darwin|linux/
        raise Error, 'pure-Ruby flashing supports macOS/Linux only; ' \
                     'on other systems flash with esptool: ' \
                     "esptool write_flash 0x0 #{image_path}"
      end

      image  = File.binread(image_path)
      serial = Serial.new(port, ROM_BAUD)
      flasher = new(serial, fd: serial.instance_variable_get(:@fd))
      begin
        flasher.enter_bootloader
        flasher.sync!
        serial = flasher.upgrade_baud(port, baud) if baud != ROM_BAUD && baud_supported?(baud)
        flasher.write_flash(image, offset: 0)
        # Verify before FLASH_END: the ROM loader has been seen going quiet
        # after that command, while MD5 right after the last block is reliable.
        flasher.verify_md5(image, offset: 0)
        flasher.finish_flash
        flasher.hard_reset
      ensure
        serial.close
      end
    end

    # The local termios layer must support the baud before CHANGE_BAUDRATE is
    # sent to the chip — once the chip switches, there is no way back without
    # a re-sync, so never request a speed we cannot reopen at.
    def self.baud_supported?(baud)
      RubySerial::Posix::BAUDE_RATES.key?(baud)
    rescue NameError
      false
    end

    # `serial` needs #read/#write; `fd` enables DTR/RTS control and may be
    # nil in tests.
    def initialize(serial, fd: nil)
      @serial = serial
      @fd     = fd
      @rxbuf  = +''.b
    end

    # ── chip reset control (DTR/RTS via the auto-download circuit) ────────

    def enter_bootloader
      # esptool's "classic reset": hold EN low, release it with IO0 low so
      # the chip starts the ROM loader, then release IO0.
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
      synced = 8.times.any? do
        @rxbuf.clear
        begin
          command(SYNC, payload, timeout: 0.5)
          drain_responses
          true
        rescue Error
          false
        end
      end
      raise Error, 'could not sync with the ESP32 boot ROM' unless synced
    end

    # CHANGE_BAUDRATE, then reopen the port at the new speed. Plain open does
    # not touch DTR/RTS (verified with rubyserial), so the chip stays in the
    # bootloader across the reopen.
    def upgrade_baud(port, baud)
      command(CHANGE_BAUD, [baud, 0].pack('V2'))
      @serial.close
      sleep 0.05
      serial = Serial.new(port, baud)
      @serial = serial
      @fd     = serial.instance_variable_get(:@fd)
      @rxbuf.clear
      serial
    end

    def write_flash(image, offset: 0)
      command(SPI_ATTACH, [0, 0].pack('V2'))
      # id, total size, block size, sector size, page size, status mask
      command(SPI_SET_PARAMS,
              [0, 4 * 1024 * 1024, 64 * 1024, 4096, 256, 0xFFFF].pack('V6'))

      blocks = (image.bytesize + FLASH_WRITE_SIZE - 1) / FLASH_WRITE_SIZE
      # The ROM erases the region inside FLASH_BEGIN; allow ~30 s per MB.
      erase_timeout = 30 * (1 + (image.bytesize / (1024 * 1024)))
      command(FLASH_BEGIN,
              [image.bytesize, blocks, FLASH_WRITE_SIZE, offset].pack('V4'),
              timeout: erase_timeout)
      stream_blocks(image, blocks)
    end

    # Every block is already committed once its FLASH_DATA is acked, so
    # FLASH_END is only a courtesy "done" (we leave the loader via hard_reset
    # anyway). The ESP32 ROM has been seen answering it with error 0x06 —
    # ignore it; the MD5 check is the source of truth.
    def finish_flash
      command(FLASH_END, [1].pack('V')) # 1 = stay in the loader
    rescue Error
      nil
    end

    def verify_md5(image, offset: 0)
      timeout = 8 * (1 + (image.bytesize / (1024 * 1024)))
      _value, data = command(SPI_FLASH_MD5,
                             [offset, image.bytesize, 0, 0].pack('V4'),
                             timeout: timeout)
      device_md5 = data[0, 32] # the ROM loader answers as 32 hex chars
      local_md5  = Digest::MD5.hexdigest(image)
      return if device_md5 == local_md5

      raise Error, "MD5 mismatch after flashing (device #{device_md5}, local #{local_md5})"
    end

    # ── request/response plumbing ──────────────────────────────────────────

    # Sends one command packet and waits for its response.
    # Returns [value, data] from the response (status bytes stripped).
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

    # Returns [value, data] when the frame is the response to `op`, raises on
    # an error status, and returns nil for unrelated frames (stale responses).
    def parse_response(frame, op)
      return nil if frame.bytesize < 8 + STATUS_BYTES || frame.getbyte(0) != 0x01 ||
                    frame.getbyte(1) != op

      value  = frame.byteslice(4, 4).unpack1('V')
      body   = frame.byteslice(8..)
      status = body.byteslice(-STATUS_BYTES, STATUS_BYTES)
      if status.getbyte(0) != 0
        raise Error, format('command 0x%<op>02x failed (error 0x%<err>02x)',
                            op: op, err: status.getbyte(1))
      end

      [value, body.byteslice(0...-STATUS_BYTES)]
    end

    # Reads from the serial port until a complete 0xC0 ... 0xC0 frame is
    # available or the deadline passes. Returns the decoded frame or nil.
    def read_frame(deadline)
      loop do
        start = @rxbuf.index("\xC0".b)
        if start
          stop = @rxbuf.index("\xC0".b, start + 1)
          if stop
            frame = @rxbuf.byteslice((start + 1)...stop)
            @rxbuf = @rxbuf.byteslice((stop + 1)..) || +''.b
            next if frame.empty? # back-to-back C0 markers

            return slip_decode(frame)
          end
        end
        return nil if Time.now > deadline

        chunk = @serial.read(256) || ''
        chunk.empty? ? sleep(0.01) : @rxbuf << chunk.b
      end
    end

    # The ROM answers a successful SYNC with a burst of identical responses;
    # swallow them so they are not mistaken for the next command's reply.
    def drain_responses
      deadline = Time.now + 0.3
      loop { break if read_frame(deadline).nil? }
    end

    def set_lines(dtr:, rts:)
      return if @fd.nil?

      io = IO.for_fd(@fd, autoclose: false)
      buf = [0].pack('L')
      io.ioctl(TIOCMGET, buf)
      bits = buf.unpack1('L')
      bits = dtr ? (bits | TIOCM_DTR) : (bits & ~TIOCM_DTR)
      bits = rts ? (bits | TIOCM_RTS) : (bits & ~TIOCM_RTS)
      io.ioctl(TIOCMSET, [bits].pack('L'))
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
