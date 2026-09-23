require_relative 'test_helper'

class SerialPortTest < Minitest::Test
  # rubyserial hands back an FFI::Pointer, which Fiddle refuses; only its raw
  # address goes through as a void*.
  FakePointer = Struct.new(:address)

  def test_handle_address_unwraps_a_pointer_object
    assert_equal 0x294, Prremote::SerialPort.handle_address(FakePointer.new(0x294))
  end

  def test_handle_address_accepts_a_bare_integer
    assert_equal 0x294, Prremote::SerialPort.handle_address(0x294)
  end

  def test_handle_address_rejects_nil_and_null
    assert_nil Prremote::SerialPort.handle_address(nil)
    assert_nil Prremote::SerialPort.handle_address(0)
    assert_nil Prremote::SerialPort.handle_address(FakePointer.new(0))
  end

  def test_windows_matches_only_windows_hosts
    %w[mswin mingw32 cygwin].each do |host|
      RbConfig::CONFIG.stub(:[], host) { assert Prremote::SerialPort.windows?, host }
    end
    %w[linux-gnu darwin24].each do |host|
      RbConfig::CONFIG.stub(:[], host) { refute Prremote::SerialPort.windows?, host }
    end
  end

  # Raising the lines is best effort: a rubyserial that stops exposing the
  # handle must not take the command down with it.
  def test_raise_modem_lines_survives_a_serial_without_a_handle
    serial = Object.new

    assert_nil Prremote::SerialPort.raise_modem_lines(serial)
  end

  def test_open_does_not_touch_modem_lines_off_windows
    skip 'Windows-only path' if Prremote::SerialPort.windows?

    called = false
    Prremote::SerialPort.stub(:raise_modem_lines, ->(_) { called = true }) do
      Serial.stub(:new, :fake_serial) do
        assert_equal :fake_serial, Prremote::SerialPort.open(File::NULL, 115_200)
      end
    end
    refute called
  end
end
