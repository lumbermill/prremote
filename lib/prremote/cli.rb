require "thor"
require_relative "version"
require_relative "detector"
require_relative "connection"
require_relative "commands/ls"
require_relative "commands/put"
require_relative "commands/get"
require_relative "commands/eval_cmd"
require_relative "commands/rm"
require_relative "commands/mkdir"
require_relative "commands/cp"
require_relative "commands/watch"
require_relative "commands/install"

module Prremote
  class CLI < Thor
    class_option :port, aliases: "-p", desc: "Serial port (default: auto-detect)"
    class_option :baud, aliases: "-b", type: :numeric, default: 115_200, desc: "Baud rate"

    def self.exit_on_failure?
      true
    end

    desc "list", "Show available prremote-compatible devices"
    def list
      devices = Detector.new.list_devices
      if devices.empty?
        puts "No serial devices found."
      else
        devices.each { |d| puts "#{d[:port]}  (#{d[:label]})" }
      end
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
      remote ||= "/home/#{File.basename(local)}"
      with_connection do |conn|
        Commands::Put.new(conn).call(local, remote)
        puts "Uploaded #{local} → #{remote}"
      end
    end

    desc "get REMOTE [LOCAL]", "Download file from device"
    def get(remote, local = nil)
      local ||= File.basename(remote)
      with_connection do |conn|
        Commands::Get.new(conn).call(remote, local)
        puts "Downloaded #{remote} → #{local}"
      end
    end

    desc "cp SRC DEST", "Copy a file on the device"
    def cp(src, dest)
      with_connection do |conn|
        Commands::Cp.new(conn).call(src, dest)
        puts "Copied #{src} → #{dest}"
      end
    end

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

    desc "watch LOCAL [REMOTE]", "Watch file for changes and auto-upload + reset"
    def watch(local, remote = nil)
      remote ||= "/home/#{File.basename(local)}"
      with_connection do |conn|
        Commands::Watch.new(conn).call(local, remote)
      end
    end

    desc "reset", "Reset (reboot) the device"
    def reset
      with_connection do |conn|
        conn.send_line("RESET")
        puts "Device rebooted."
      end
    end

    desc "install", "Download and install prremote firmware to Pico"
    option :board, default: "pico", desc: "Board type: pico, pico_w"
    option :list, type: :boolean, default: false, desc: "List available firmware versions"
    def install
      Commands::Install.new.call(board: options[:board], list_versions: options[:list])
    rescue RuntimeError => e
      raise Thor::Error, e.message
    end

    desc "version", "Show prremote and device firmware version"
    def version
      puts "prremote #{VERSION}"
      with_connection do |conn|
        conn.send_line("VERSION")
        fw = conn.read_line
        puts "Firmware: #{fw}"
      end
    end

    private

    def resolve_port
      return options[:port] if options[:port]

      port = Detector.find_device
      raise Thor::Error, "No prremote device found. Use --port to specify one." unless port

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
    rescue ProtocolError => e
      raise Thor::Error, "Protocol error: #{e.message}"
    ensure
      conn&.close
    end
  end
end
