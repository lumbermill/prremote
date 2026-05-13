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
      @detector.stub(:serial_ports, ["/dev/ttyACM0"]) do
        assert_equal "/dev/ttyACM0", Prremote::Detector.find_device
      end
    end
  end
end
