require_relative 'test_helper'

class DetectorTest < Minitest::Test
  def setup
    @detector = Prremote::Detector.new
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

    @detector.stub(:ioreg_usb, '"idVendor" = 0x10c4') do
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
