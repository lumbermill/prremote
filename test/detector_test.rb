require_relative "test_helper"

class DetectorTest < Minitest::Test
  def setup
    @detector = Prremote::Detector.new
  end

  def test_list_devices_returns_array
    assert_kind_of Array, @detector.list_devices
  end

  def test_list_devices_entry_has_port_and_label
    @detector.stub(:serial_ports, ["/dev/ttyACM0"]) do
      @detector.stub(:r2p2_port?, true) do
        entry = @detector.list_devices.first
        assert entry.key?(:port)
        assert entry.key?(:label)
      end
    end
  end

  def test_find_device_returns_nil_when_no_ports
    @detector.stub(:serial_ports, []) do
      assert_nil Prremote::Detector.find_device
    end
  end

  def test_find_device_returns_only_port
    stub_detector = Prremote::Detector.new
    stub_detector.stub(:serial_ports, ["/dev/ttyACM0"]) do
      stub_detector.stub(:r2p2_port?, false) do
        assert_equal "/dev/ttyACM0", stub_detector.send(:serial_ports).first
      end
    end
  end
end
