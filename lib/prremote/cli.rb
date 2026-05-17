require 'thor'
require 'rubyserial'
require_relative 'version'
require_relative 'detector'
require_relative 'mrbc'
require_relative 'runtime_manager'
require_relative 'commands/install'
require_relative 'commands/deploy'
require_relative 'commands/undeploy'
require_relative 'commands/run'
require_relative 'commands/eval_cmd'
require_relative 'commands/watch'

module Prremote
  class CLI < Thor
    class_option :port, aliases: '-p', desc: 'Serial port (default: auto-detect)'
    class_option :baud, aliases: '-b', type: :numeric, default: 115_200, desc: 'Baud rate'

    def self.exit_on_failure?
      true
    end

    remove_command :tree

    desc 'install', 'Flash prremote runtime firmware to Pico W or Pico'
    option :version, type: :string, desc: "Firmware version to install (default: #{RUNTIME_VERSION})"
    option :board, type: :string, desc: 'Board type: pico or picow (default: picow)'
    def install
      version = options[:version] || RUNTIME_VERSION
      board = options[:board] || 'picow'
      unless RuntimeManager::BOARDS.include?(board)
        raise Thor::Error, "Unknown board '#{board}'. Valid values: #{RuntimeManager::BOARDS.join(', ')}"
      end

      Commands::Install.new(version: version, board: board).call
    rescue StandardError => e
      raise Thor::Error, e.message
    end

    desc 'run FILE', 'Compile and run a Ruby script on the device (one-shot)'
    def run_script(file)
      port = resolve_port
      Commands::Run.new(port: port, baud: options[:baud]).call(file)
    rescue StandardError => e
      raise Thor::Error, e.message
    end
    map 'run' => :run_script

    desc 'deploy FILE', 'Compile and save a Ruby script to flash (auto-runs on boot)'
    def deploy(file)
      port = resolve_port
      Commands::Deploy.new(port: port, baud: options[:baud]).call(file)
    rescue StandardError => e
      raise Thor::Error, e.message
    end

    desc 'undeploy', 'Erase the deployed script from flash (disables auto-run on boot)'
    def undeploy
      port = resolve_port
      Commands::Undeploy.new(port: port, baud: options[:baud]).call
    rescue StandardError => e
      raise Thor::Error, e.message
    end

    desc 'eval EXPR', 'Compile and run a one-liner Ruby expression on the device'
    def eval(expr)
      port = resolve_port
      Commands::EvalCmd.new(port: port, baud: options[:baud]).call(expr)
    rescue StandardError => e
      raise Thor::Error, e.message
    end

    desc 'watch FILE', 'Watch a Ruby file for changes and re-run on the device automatically'
    def watch(file)
      port = resolve_port
      Commands::Watch.new(port: port, baud: options[:baud]).call(file)
    rescue StandardError => e
      raise Thor::Error, e.message
    end

    desc 'list', 'Show available serial devices'
    def list
      devices = Detector.new.list_devices
      if devices.empty?
        puts 'No serial devices found.'
      else
        devices.each { |d| puts "#{d[:port]}  (#{d[:label]})" }
      end
    end

    desc 'reset', 'Send Ctrl+C to interrupt the running program'
    def reset
      port = resolve_port
      serial = Serial.new(port, options[:baud])
      serial.write("\x03")
      sleep 0.1
      puts 'Reset signal sent.'
    rescue StandardError => e
      raise Thor::Error, e.message
    ensure
      serial&.close
    end

    desc 'version', 'Show prremote, mrbc, and device firmware version'
    def version
      puts "prremote: #{VERSION}"

      begin
        puts "mrbc:     #{Mrbc.version} (#{Mrbc.bin})"
      rescue StandardError => e
        puts "mrbc:     (#{e.message})"
      end

      puts "runtime:  #{fetch_runtime_version}"
    end

    private

    def fetch_runtime_version # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      port = options[:port] || Detector.find_device
      return '(no device connected)' unless port

      serial = Serial.new(port, options[:baud])
      serial.write("\x03")
      buf      = +''
      deadline = Time.now + 5

      loop do
        begin
          buf << (serial.read(256) || '').gsub("\r\n", "\n").gsub("\r", '')
        rescue StandardError
          # Watchdog reboot dropped USB; wait for re-enumeration then reopen.
          begin
            serial.close
          rescue StandardError
            nil
          end
          serial = nil
          reopen_deadline = [deadline, Time.now + 8].min
          loop do
            return '(not responding)' if Time.now > reopen_deadline

            p = options[:port] || Detector.find_device
            if p && File.exist?(p)
              serial = begin
                Serial.new(p, options[:baud])
              rescue StandardError
                nil
              end
              break if serial
            end
            sleep 0.3
          end
          buf = +''
          next
        end

        return ::Regexp.last_match(1) if buf =~ %r{READY prremote-runtime/([\d.]+)}
        return '(not responding)' if Time.now > deadline

        sleep 0.05
      end
    rescue StandardError => e
      "(#{e.message})"
    ensure
      serial&.close
    end

    def resolve_port
      return options[:port] if options[:port]

      port = Detector.find_device
      raise Thor::Error, 'No device found. Use --port to specify one.' unless port

      port
    end
  end
end
