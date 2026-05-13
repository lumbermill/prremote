require "rubyserial"

module Prremote
  class Connection
    # Matches CSI escape sequences (covers \e[?25l, \e[1G, \e[0K, etc.)
    ANSI_RE   = /\e\[[\x30-\x3f]*[\x20-\x2f]*[\x40-\x7e]/
    SHELL_RE  = /\$> \z/
    IRB_RE    = /irb> \z/
    EITHER_RE = /(?:\$|irb)> \z/
    TIMEOUT   = 10.0

    attr_reader :port, :baud

    def initialize(port:, baud: 115_200)
      @port = port
      @baud = baud
      @serial = nil
    end

    def open
      @serial = Serial.new(port, baud)
      sleep 0.5
      @serial.read(4096)    # discard boot noise / any pending output
      @serial.write("\x03") # Ctrl-C: interrupt any running operation
      sleep 0.2             # let the device process the interrupt
      @serial.read(4096)    # drain the interrupt echo/response
      @serial.write("\r\n") # request a fresh shell prompt
      raw = read_raw_until_prompt(prompt: EITHER_RE, timeout: 5.0)
      if strip_ansi(raw).gsub("\r", "").match?(IRB_RE)
        @serial.write("exit\r\n")
        read_raw_until_prompt(prompt: SHELL_RE, timeout: 5.0)
      end
      self
    end

    def close
      @serial&.close
      @serial = nil
    end

    # Send a shell command and return the clean output.
    def run(cmd, timeout: TIMEOUT)
      @serial.write("#{cmd}\r\n")
      raw = read_raw_until_prompt(prompt: SHELL_RE, timeout: timeout)
      parse_output(raw)
    end

    # Evaluate a Ruby expression via irb mode and return the result.
    def eval_ruby(expr, timeout: TIMEOUT)
      @serial.write("irb\r\n")
      read_raw_until_prompt(prompt: IRB_RE, timeout: 5.0)

      @serial.write("#{expr}\r\n")
      raw = read_raw_until_prompt(prompt: IRB_RE, timeout: timeout)
      result = parse_output(raw).sub(/\A=> /, "")

      @serial.write("exit\r\n")
      read_raw_until_prompt(prompt: SHELL_RE, timeout: 5.0)

      result
    end

    def open?
      !@serial.nil?
    end

    def reboot
      @serial.write("reboot\r\n")
      sleep 0.1
    end

    private

    def read_raw_until_prompt(prompt:, timeout: TIMEOUT)
      buf      = +""
      deadline = Time.now + timeout

      loop do
        chunk = @serial.read(256)
        buf << chunk if chunk && !chunk.empty?
        break if strip_ansi(buf).gsub("\r", "").match?(prompt)
        raise TimeoutError, "Timed out waiting for prompt on #{port}" if Time.now > deadline

        sleep 0.01
      end

      buf
    end

    def parse_output(raw)
      clean = strip_ansi(raw).gsub("\r\n", "\n").gsub("\r", "")
      # First line is the character-by-character echo; drop it
      _echo, rest = clean.split("\n", 2)
      return "" unless rest

      # Remove trailing prompt redraws
      rest.gsub(/(?:irb|\$)> *\n?/, "").strip
    end

    def strip_ansi(str)
      str.gsub(ANSI_RE, "")
    end
  end

  class TimeoutError < StandardError; end
end
