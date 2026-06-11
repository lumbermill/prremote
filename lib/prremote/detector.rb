require 'rbconfig'

module Prremote
  class Detector
    # Known USB vendor IDs → device label and the macOS port-name pattern.
    # Pico exposes native USB CDC (usbmodem); ESP32 boards sit behind a
    # USB-UART bridge (usbserial): CP210x on M5GO/M5Stack, CH910x on newer
    # revisions.
    KNOWN_VENDORS = {
      '2e8a' => { label: 'Pico (prremote/R2P2)', macos: /usbmodem/ },
      '10c4' => { label: 'ESP32 (CP210x)',       macos: /usbserial/ },
      '1a86' => { label: 'ESP32 (CH910x)',       macos: /usbserial/ }
    }.freeze
    R2P2_VENDOR_IDS = %w[2e8a].freeze # Raspberry Pi USB VID (kept for compat)

    def self.find_device
      new.find_device
    end

    def find_device
      candidates = serial_ports
      return candidates.first if candidates.size == 1

      known = candidates.select { |p| known_port?(p) }
      known.first || candidates.first
    end

    def list_devices
      serial_ports.map do |port|
        { port: port, label: port_label(port) || 'unknown' }
      end
    end

    private

    def serial_ports
      case RbConfig::CONFIG['host_os']
      when /darwin/
        # Use cu.* (call-out) devices — tty.* blocks on carrier and causes EBUSY
        Dir.glob('/dev/cu.usbmodem*') + Dir.glob('/dev/cu.usbserial*')
      when /linux/
        Dir.glob('/dev/ttyACM*') + Dir.glob('/dev/ttyUSB*')
      when /mswin|mingw|cygwin/
        # Enumerate COM ports via registry on Windows
        require 'win32/registry'
        ports = []
        Win32::Registry::HKEY_LOCAL_MACHINE.open('HARDWARE\DEVICEMAP\SERIALCOMM') do |reg|
          reg.each_value { |_name, _type, data| ports << data }
        end
        ports
      else
        []
      end
    end

    def known_port?(port)
      !port_label(port).nil?
    end

    def port_label(port)
      # On macOS/Linux, check ioreg or sysfs for a known vendor ID
      case RbConfig::CONFIG['host_os']
      when /darwin/
        KNOWN_VENDORS.each do |vid, info|
          return info[:label] if usb_vendor_ids.include?(vid) && port.match?(info[:macos])
        end
        nil
      when /linux/
        port_name = File.basename(port)
        vid_path = "/sys/class/tty/#{port_name}/device/../../../idVendor"
        return nil unless File.exist?(vid_path)

        vid = File.read(vid_path).strip.downcase
        KNOWN_VENDORS.dig(vid, :label)
      end
    end

    # Vendor IDs of all connected USB devices as 4-digit hex strings.
    # ioreg prints idVendor in decimal (e.g. 4292 for 0x10c4).
    def usb_vendor_ids
      @usb_vendor_ids ||= ioreg_usb.scan(/"idVendor" = (\d+)/)
                                   .map { |(dec)| format('%04x', dec.to_i) }
    end

    def ioreg_usb
      @ioreg_usb ||= `ioreg -p IOUSB -l 2>/dev/null`
    end
  end
end
