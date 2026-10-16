require_relative 'test_helper'
require 'tmpdir'
require 'fileutils'

class DetectorTest < Minitest::Test
  def setup
    @detector = Prremote::Detector.new
  end

  # Mirrors the sysfs shape of a tty node: the device link lands on the USB
  # interface, and idVendor sits some way above it. Returns the interface dir.
  def with_sysfs_tree(depth:, vendor: nil)
    Dir.mktmpdir do |root|
      File.write(File.join(root, 'idVendor'), "#{vendor}\n") if vendor
      interface = File.join(root, Array.new(depth) { |i| "level#{i}" }.join('/'))
      FileUtils.mkdir_p(interface)
      yield interface
    end
  end

  def test_linux_vendor_id_walks_up_to_the_usb_device
    skip 'Linux-only lookup' unless RbConfig::CONFIG['host_os'] =~ /linux/

    # Under WSL the chain hangs off vhci_hcd, which sits at a different depth
    # than the PCI controller a native host walks up to.
    with_sysfs_tree(depth: 3, vendor: '2e8a') do |interface|
      File.stub(:realpath, interface) do
        assert_equal '2e8a', @detector.send(:linux_vendor_id, '/dev/ttyACM0')
      end
    end
  end

  def test_linux_vendor_id_finds_vendor_directly_above_the_interface
    skip 'Linux-only lookup' unless RbConfig::CONFIG['host_os'] =~ /linux/

    with_sysfs_tree(depth: 1, vendor: '10c4') do |interface|
      File.stub(:realpath, interface) do
        assert_equal '10c4', @detector.send(:linux_vendor_id, '/dev/ttyUSB0')
      end
    end
  end

  def test_linux_vendor_id_returns_nil_when_no_vendor_file
    skip 'Linux-only lookup' unless RbConfig::CONFIG['host_os'] =~ /linux/

    with_sysfs_tree(depth: 3) do |interface|
      File.stub(:realpath, interface) do
        assert_nil @detector.send(:linux_vendor_id, '/dev/ttyACM0')
      end
    end
  end

  def test_linux_vendor_id_returns_nil_for_missing_port
    skip 'Linux-only lookup' unless RbConfig::CONFIG['host_os'] =~ /linux/

    assert_nil @detector.send(:linux_vendor_id, '/dev/ttyACM-does-not-exist')
  end

  def test_list_devices_returns_array
    assert_kind_of Array, @detector.list_devices
  end

  def test_list_devices_entry_has_port_and_label
    @detector.stub(:serial_ports, ['/dev/ttyACM0']) do
      @detector.stub(:port_label, 'Pico (prremote/R2P2)') do
        entry = @detector.list_devices.first
        assert entry.key?(:port)
        assert entry.key?(:label)
      end
    end
  end

  def test_find_device_prefers_known_vendor_port
    label_for = ->(port) { port.include?('usbserial') ? 'ESP32 (CP210x)' : nil }
    Prremote::Detector.stub(:new, @detector) do
      @detector.stub(:serial_ports, ['/dev/cu.usbmodem-junk', '/dev/cu.usbserial-0001']) do
        @detector.stub(:port_label, label_for) do
          assert_equal '/dev/cu.usbserial-0001', Prremote::Detector.find_device
        end
      end
    end
  end

  def test_port_label_maps_esp32_bridge_vid_on_macos
    skip 'macOS-only check' unless RbConfig::CONFIG['host_os'] =~ /darwin/

    # ioreg prints idVendor in decimal: 4292 == 0x10c4 (CP210x)
    @detector.stub(:ioreg_usb, '"idVendor" = 4292') do
      assert_equal 'ESP32 (CP210x)', @detector.send(:port_label, '/dev/cu.usbserial-0001')
      assert_nil @detector.send(:port_label, '/dev/cu.usbmodem1101')
    end
  end

  def test_find_device_returns_nil_when_no_ports
    # Detector.find_device calls new.find_device, so stub Detector.new to return
    # the pre-configured instance.
    Prremote::Detector.stub(:new, @detector) do
      @detector.stub(:serial_ports, []) do
        assert_nil Prremote::Detector.find_device
      end
    end
  end

  def test_find_device_returns_first_port_when_only_one
    Prremote::Detector.stub(:new, @detector) do
      @detector.stub(:serial_ports, ['/dev/ttyACM0']) do
        assert_equal '/dev/ttyACM0', Prremote::Detector.find_device
      end
    end
  end
end
