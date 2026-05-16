require "thor"
require_relative "version"
require_relative "detector"
require_relative "connection"
require_relative "runtime_manager"
require_relative "commands/install"
require_relative "commands/deploy"
require_relative "commands/ls"
require_relative "commands/put"
require_relative "commands/get"
require_relative "commands/run"
require_relative "commands/eval_cmd"
require_relative "commands/rm"
require_relative "commands/mkdir"

module Prremote
  class CLI < Thor
    class_option :port, aliases: "-p", desc: "Serial port (default: auto-detect)"
    class_option :baud, aliases: "-b", type: :numeric, default: 115_200, desc: "Baud rate"

    def self.exit_on_failure?
      true
    end

    desc "install", "Flash prremote runtime firmware to Pico W"
    option :version, type: :string, desc: "Firmware version to install (default: #{RUNTIME_VERSION})"
    def install
      version = options[:version] || RUNTIME_VERSION
      Commands::Install.new(version: version).call
    rescue RuntimeError => e
      raise Thor::Error, e.message
    end

    desc "deploy FILE", "Compile and run a Ruby script on the device"
    def deploy(file)
      port = resolve_port
      Commands::Deploy.new(port: port, baud: options[:baud]).call(file)
    rescue RuntimeError => e
      raise Thor::Error, e.message
    end

    desc "list", "Show available R2P2/PicoRuby devices"
    def list
      devices = Detector.new.list_devices
      if devices.empty?
        puts "No serial devices found."
      else
        devices.each { |d| puts "#{d[:port]}  (#{d[:label]})" }
      end
    end

    desc "repl", "Open interactive REPL on device"
    def repl
      port = resolve_port
      puts "Connecting to #{port} at #{options[:baud]} baud… (Ctrl-C to exit)"
      conn = Connection.new(port: port, baud: options[:baud]).open

      # Hand off to a simple line-loop REPL
      loop do
        print "prremote> "
        line = $stdin.gets
        break unless line

        line = line.chomp
        next if line.empty?
        break if line == "exit"

        begin
          result = conn.run(line)
          puts result unless result.empty?
        rescue TimeoutError => e
          warn "Timeout: #{e.message}"
        end
      end
    ensure
      conn&.close
    end

    desc "irb", "Open interactive Ruby shell on device"
    def irb
      port = resolve_port
      puts "Connecting to #{port} at #{options[:baud]} baud… (Ctrl-C to exit)"
      conn = Connection.new(port: port, baud: options[:baud]).open
      loop do
        print "irb> "
        line = $stdin.gets
        break unless line

        line = line.chomp
        next if line.empty?
        break if line == "exit"

        begin
          result = conn.run(line)
          puts result unless result.empty?
        rescue TimeoutError => e
          warn "Timeout: #{e.message}"
        end
      end
    rescue Interrupt
      # user hit Ctrl-C
    ensure
      conn&.close
    end

    desc "ls [PATH]", "List files on device"
    def ls(path = "/home")
      with_connection do |conn|
        entries = Commands::Ls.new(conn).call(path)
        entries.each { |e| puts e }
      end
    end

    desc "put LOCAL [REMOTE]", "Upload file to device"
    def put(local, remote = nil)
      remote ||= "/#{File.basename(local)}"
      with_connection do |conn|
        Commands::Put.new(conn).call(local, remote)
        puts "Uploaded #{local} -> #{remote}"
      end
    end

    desc "get REMOTE [LOCAL]", "Download file from device"
    def get(remote, local = nil)
      local ||= File.basename(remote)
      with_connection do |conn|
        Commands::Get.new(conn).call(remote, local)
        puts "Downloaded #{remote} -> #{local}"
      end
    end

    desc "run FILE", "Run a local Ruby script on device"
    def run_script(file)
      with_connection do |conn|
        output = Commands::Run.new(conn).call(file)
        puts output unless output.empty?
      end
    end
    map "run" => :run_script

    desc "eval EXPR", "Evaluate a Ruby expression on device"
    def eval(expr)
      with_connection do |conn|
        result = Commands::EvalCmd.new(conn).call(expr)
        puts result unless result.empty?
      end
    end

    desc "rm PATH", "Remove a file on device"
    def rm(path)
      with_connection do |conn|
        Commands::Rm.new(conn).call(path)
        puts "Removed #{path}"
      end
    end

    desc "mkdir PATH", "Create directory on device"
    def mkdir(path)
      with_connection do |conn|
        Commands::Mkdir.new(conn).call(path)
        puts "Created #{path}"
      end
    end

    VOLUME_ROOT = "/Volumes/R2P2"

    desc "reset", "Interrupt running program and reboot the device"
    def reset
      port = resolve_port
      serial = Serial.new(port, options[:baud])
      serial.write("\x03")
      sleep 0.1
      puts "Reset signal sent."
    rescue RuntimeError => e
      raise Thor::Error, e.message
    ensure
      serial&.close
    end

    desc "open [REMOTE]", "Open device path in Finder (macOS only)"
    def open(remote = "/home")
      raise Thor::Error, "'open' is only supported on macOS." unless RUBY_PLATFORM.include?("darwin")

      path = File.join(VOLUME_ROOT, remote)
      raise Thor::Error, "Volume not found: #{VOLUME_ROOT}\n  Is R2P2 connected and mounted?" unless File.exist?(VOLUME_ROOT)

      system("open", path)
    end

    desc "version", "Show prremote and device firmware version"
    def version
      puts "prremote #{VERSION}"

      port = options[:port] || Detector.find_device
      unless port
        puts "Device runtime: (no device connected)"
        return
      end

      serial = Serial.new(port, options[:baud])
      # Send Ctrl+C so a running program is interrupted and device re-sends READY
      serial.write("\x03")

      buf = +""
      deadline = Time.now + 5
      loop do
        buf << (serial.read(256) || "").gsub("\r\n", "\n").gsub("\r", "")
        if buf =~ /READY prremote-runtime\/([\d.]+)/
          puts "Device runtime: #{$1}"
          return
        end
        break if Time.now > deadline
        sleep 0.05
      end
      puts "Device runtime: (not responding)"
    ensure
      serial&.close
    end

    private

    def resolve_port
      return options[:port] if options[:port]

      port = Detector.find_device
      raise Thor::Error, "No R2P2 device found. Use --port to specify one." unless port

      port
    end

    def with_connection
      port = resolve_port
      warn "Connecting to #{port}…"
      conn = Connection.new(port: port, baud: options[:baud]).open
      yield conn
    rescue RubySerial::Error => e
      raise Thor::Error, "Failed to open #{port}: #{e.message}\n" \
                         "  - Is another program (screen, minicom, Arduino IDE) using the port?\n" \
                         "  - Try: prremote list"
    rescue TimeoutError => e
      raise Thor::Error, "Timeout: #{e.message}"
    ensure
      conn&.close
    end
  end
end
