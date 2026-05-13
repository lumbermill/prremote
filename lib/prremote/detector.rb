require "rbconfig"

module Prremote
  class Detector
    R2P2_VENDOR_IDS = %w[2e8a].freeze  # Raspberry Pi USB VID

    def self.find_device
      new.find_device
    end

    def find_device
      candidates = serial_ports
      return candidates.first if candidates.size == 1

      r2p2 = candidates.select { |p| r2p2_port?(p) }
      r2p2.first || candidates.first
    end

    def list_devices
      serial_ports.map do |port|
        label = r2p2_port?(port) ? "R2P2/PicoRuby" : "unknown"
        { port: port, label: label }
      end
    end

    private

    def serial_ports
      case RbConfig::CONFIG["host_os"]
      when /darwin/
        # Use cu.* (call-out) devices — tty.* blocks on carrier and causes EBUSY
        Dir.glob("/dev/cu.usbmodem*") + Dir.glob("/dev/cu.usbserial*")
      when /linux/
        Dir.glob("/dev/ttyACM*") + Dir.glob("/dev/ttyUSB*")
      when /mswin|mingw|cygwin/
        # Enumerate COM ports via registry on Windows
        require "win32/registry"
        ports = []
        Win32::Registry::HKEY_LOCAL_MACHINE.open('HARDWARE\DEVICEMAP\SERIALCOMM') do |reg|
          reg.each_value { |_name, _type, data| ports << data }
        end
        ports
      else
        []
      end
    end

    def r2p2_port?(port)
      # On macOS/Linux, check sysfs or ioreg for the Raspberry Pi VID
      case RbConfig::CONFIG["host_os"]
      when /darwin/
        ioreg_output = `ioreg -p IOUSB -l 2>/dev/null`
        R2P2_VENDOR_IDS.any? { |vid| ioreg_output.include?(vid) } &&
          port.match?(/usbmodem/)
      when /linux/
        port_name = File.basename(port)
        vid_path = "/sys/class/tty/#{port_name}/device/../../../idVendor"
        return false unless File.exist?(vid_path)

        vid = File.read(vid_path).strip.downcase
        R2P2_VENDOR_IDS.include?(vid)
      else
        false
      end
    end
  end
end
