require "rubyserial"

module Prremote
  class Connection
    TIMEOUT = 10.0

    attr_reader :port, :baud

    def initialize(port:, baud: 115_200)
      @port = port
      @baud = baud
      @serial = nil
    end

    def open
      @serial = Serial.new(@port, @baud)
      self
    end

    def close
      @serial&.close
      @serial = nil
    end

    def open?
      !@serial.nil?
    end

    def send_line(text)
      @serial.write("#{text}\r\n")
    end

    def read_line(timeout: TIMEOUT)
      buf = +""
      deadline = Time.now + timeout
      loop do
        ch = @serial.read(1)
        if ch && !ch.empty?
          buf << ch
          return buf.chomp.delete("\r") if buf.end_with?("\n")
        end
        raise TimeoutError, "Timed out reading from #{@port}" if Time.now > deadline

        sleep 0.001
      end
    end

    def write_bytes(data)
      @serial.write(data)
    end

    def read_bytes(n, timeout: TIMEOUT)
      return "".b if n == 0

      buf = "".b
      deadline = Time.now + timeout
      loop do
        remaining = n - buf.bytesize
        chunk = @serial.read([remaining, 256].min)
        buf << chunk.b if chunk && !chunk.empty?
        return buf if buf.bytesize >= n
        raise TimeoutError, "Timed out reading #{n} bytes from #{@port}" if Time.now > deadline

        sleep 0.001
      end
    end
  end

  class TimeoutError < StandardError; end
  class ProtocolError < StandardError; end
end
