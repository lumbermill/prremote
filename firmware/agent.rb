VERSION = "0.1.0"
APP_PATH = "/home/app.rb"
# How long (ms) to wait for 0x03 before running app.rb.
# Short enough to feel instant; long enough for the host to send 0x03 after reset.
BOOT_WAIT_MS = 200

uart = UART.new(unit: :USB, baudrate: 115200)

def uart_read_bytes(uart, size)
  buf = "".b
  while buf.bytesize < size
    chunk = uart.readpartial(size - buf.bytesize)
    buf << chunk.b if chunk && !chunk.empty?
  end
  buf
end

def run_app(uart, app_path)
  uart.flush
  load app_path
rescue => e
  uart.write("ERROR app: #{e.message}\r\n")
end

# On boot, peek at the serial port for BOOT_WAIT_MS.
# If 0x03 (Ctrl+C) arrives → stay in agent mode.
# Otherwise, run app.rb immediately (if it exists).
# prremote's `reset` command sends 0x03 right after triggering the reset,
# so it will almost always win the race.
def boot_peek(uart, app_path, wait_ms)
  deadline_us = Time.now.to_f + wait_ms / 1000.0
  while Time.now.to_f < deadline_us
    c = uart.readpartial(1)
    next unless c && !c.empty?
    return c  # hand first byte back to the command loop
  end

  if File.exist?(app_path)
    run_app(uart, app_path)
  end

  nil
end

# --- Main agent loop ---

first_byte = boot_peek(uart, APP_PATH, BOOT_WAIT_MS)

loop do
  line = ""
  line << first_byte if first_byte
  first_byte = nil

  while true
    c = uart.readpartial(1)
    next unless c && !c.empty?

    # 0x03 (Ctrl+C): interrupt whatever was running, re-enter agent mode
    if c == "\x03"
      uart.write("INFO agent ready\r\n")
      break
    end

    line << c
    break if c == "\n"
  end

  line = line.chomp.delete("\r")
  next if line.empty?

  parts = line.split(" ")
  cmd  = parts[0]
  args = parts.slice(1, parts.size)

  case cmd
  when "PUT"
    path = args[0]
    size = args[1].to_i
    uart.write("READY\r\n")
    data = uart_read_bytes(uart, size)
    File.open(path, "wb") { |f| f.write(data) }
    uart.write("OK\r\n")

  when "GET"
    path = args[0]
    raise "file not found: #{path}" unless File.exist?(path)
    data = File.open(path, "rb") { |f| f.read }
    uart.write("SIZE #{data.bytesize}\r\n")
    uart.write(data)

  when "LS"
    path = args[0] || "/"
    entries = Dir.entries(path)
    entries.each { |e| uart.write("#{e}\r\n") }
    uart.write("END\r\n")

  when "MKDIR"
    Dir.mkdir(args[0])
    uart.write("OK\r\n")

  when "RM"
    File.delete(args[0])
    uart.write("OK\r\n")

  when "CP"
    src, dst = args[0], args[1]
    data = File.open(src, "rb") { |f| f.read }
    File.open(dst, "wb") { |f| f.write(data) }
    uart.write("OK\r\n")

  when "EVAL"
    code = args.join(" ")
    result = eval(code)
    uart.write("OK #{result}\r\n")

  when "RESET"
    uart.write("OK\r\n")
    uart.flush
    Machine.reset

  when "VERSION"
    uart.write("OK prremote-agent #{VERSION}\r\n")

  else
    uart.write("ERROR unknown command: #{cmd}\r\n")
  end
rescue => e
  uart.write("ERROR #{e.message}\r\n")
end
