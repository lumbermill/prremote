require_relative 'test_helper'

class WslHintTest < Minitest::Test
  def teardown
    Prremote::Detector.instance_variable_set(:@wsl, nil)
  end

  def stub_wsl(value)
    Prremote::Detector.instance_variable_set(:@wsl, value)
  end

  def test_no_hint_outside_wsl
    stub_wsl(false)

    assert_nil Prremote::Detector.no_device_hint
  end

  def test_hint_names_usbipd_under_wsl
    stub_wsl(true)
    hint = Prremote::Detector.no_device_hint

    refute_nil hint
    assert_match(/usbipd/, hint)
  end

  # WSL2 reports itself through /proc/version; a plain Linux kernel does not.
  def test_wsl_detection_reads_proc_version
    Prremote::Detector.instance_variable_set(:@wsl, nil)
    RbConfig::CONFIG.stub(:[], 'linux-gnu') do
      File.stub(:file?, true) do
        File.stub(:read, 'Linux version 6.6.87.2-microsoft-standard-WSL2') do
          assert Prremote::Detector.wsl?
        end
      end
    end
  end

  def test_wsl_detection_false_on_plain_linux
    Prremote::Detector.instance_variable_set(:@wsl, nil)
    RbConfig::CONFIG.stub(:[], 'linux-gnu') do
      File.stub(:file?, true) do
        File.stub(:read, 'Linux version 6.8.0-generic') do
          refute Prremote::Detector.wsl?
        end
      end
    end
  end
end
