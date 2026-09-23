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

    # How far above the tty node the USB device sits is not fixed: ttyUSB
    # bridges add a level that the native-CDC ttyACM nodes do not, and under
    # WSL the chain hangs off vhci_hcd rather than a PCI controller. The lookup
    # walks up until idVendor turns up instead of guessing a depth.
    SYSFS_WALK_LIMIT = 6

    WINDOWS_USB_ENUM = 'SYSTEM\CurrentControlSet\Enum\USB'.freeze
    WINDOWS_SERIALCOMM = 'HARDWARE\DEVICEMAP\SERIALCOMM'.freeze

    def self.find_device
      new.find_device
    end

    # WSL2 does not forward USB devices to the guest: a board Windows enumerates
    # correctly still has no /dev/ttyACM* here until usbipd-win attaches it.
    def self.wsl?
      return @wsl unless @wsl.nil?

      @wsl = RbConfig::CONFIG['host_os'].match?(/linux/) &&
             File.file?('/proc/version') &&
             File.read('/proc/version').downcase.include?('microsoft')
    rescue SystemCallError
      @wsl = false
    end

    # Appended wherever a missing device would otherwise look like a prremote
    # bug, since under WSL the cause is almost always the missing attach.
    def self.no_device_hint
      return nil unless wsl?

      'Running under WSL: attach the board with usbipd-win first — ' \
        '`usbipd list`, then `usbipd attach --wsl --busid <BUSID>`.'
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
        (windows_usb_ports.keys + windows_serialcomm_ports).uniq
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
        vid = linux_vendor_id(port)
        vid && KNOWN_VENDORS.dig(vid, :label)
      when /mswin|mingw|cygwin/
        KNOWN_VENDORS.dig(windows_usb_ports[port], :label)
      end
    end

    # Windows records the COM port it assigned to each USB device under that
    # device's Enum key, which is also the only place the VID is reachable.
    # SERIALCOMM lists port names but says nothing about what sits behind them,
    # so a Bluetooth virtual port would otherwise be indistinguishable from a
    # board — and, being first in the list, would be picked over it.
    def windows_usb_ports
      @windows_usb_ports ||= begin
        require 'win32/registry'
        collect_windows_usb_ports
      rescue ::Win32::Registry::Error, LoadError
        {}
      end
    end

    def collect_windows_usb_ports
      ports = {}
      Win32::Registry::HKEY_LOCAL_MACHINE.open(WINDOWS_USB_ENUM) do |usb|
        usb.each_key do |vid_pid, _|
          vid = vid_pid[/VID_(\h{4})/i, 1]
          next unless vid

          usb.open(vid_pid) do |device|
            device.each_key do |instance, _|
              name = windows_port_name(device, instance)
              ports[name] = vid.downcase if name
            end
          end
        end
      end
      ports
    end

    def windows_port_name(device, instance)
      device.open("#{instance}\\Device Parameters") { |params| params['PortName'] }
    rescue ::Win32::Registry::Error
      nil
    end

    # Ruby's registry reader strips the last character of a REG_SZ value stored
    # without its NUL terminator, which some drivers omit: the Bluetooth stack's
    # entries come back as "COM" with the number eaten. Anything that is not a
    # whole COM<number> cannot be opened, so it is dropped rather than offered.
    def windows_serialcomm_ports
      require 'win32/registry'
      ports = []
      Win32::Registry::HKEY_LOCAL_MACHINE.open(WINDOWS_SERIALCOMM) do |reg|
        reg.each_value { |_name, _type, data| ports << data if data.to_s.match?(/\ACOM\d+\z/) }
      end
      ports
    rescue ::Win32::Registry::Error, LoadError
      []
    end

    def linux_vendor_id(port)
      dir = File.realpath("/sys/class/tty/#{File.basename(port)}/device")
      SYSFS_WALK_LIMIT.times do
        vid_path = File.join(dir, 'idVendor')
        return File.read(vid_path).strip.downcase if File.file?(vid_path)

        parent = File.dirname(dir)
        break if parent == dir

        dir = parent
      end
      nil
    rescue SystemCallError
      nil
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
