require_relative "test_helper"

class FakeSerial
  attr_reader :written

  def initialize(input = "")
    @buf = input.dup.b
    @written = []
  end

  def write(data)
    @written << data
  end

  def read(n)
    @buf.slice!(0, n) || ""
  end

  def close; end
end

class ConnectionTest < Minitest::Test
  def make_conn(input = "")
    fake = FakeSerial.new(input)
    Serial.stub(:new, fake) do
      conn = Prremote::Connection.new(port: "/dev/ttyACM0")
      conn.open
      yield conn, fake
    end
  end

  def test_open_marks_connection_as_open
    make_conn { |conn| assert conn.open? }
  end

  def test_close_marks_connection_as_closed
    make_conn do |conn|
      conn.close
      refute conn.open?
    end
  end

  def test_send_line_writes_crlf_terminated_text
    make_conn do |conn, fake|
      conn.send_line("HELLO")
      assert_includes fake.written, "HELLO\r\n"
    end
  end

  def test_read_line_returns_line_without_crlf
    make_conn("OK\r\n") do |conn|
      assert_equal "OK", conn.read_line
    end
  end

  def test_read_line_strips_lone_lf
    make_conn("READY\n") do |conn|
      assert_equal "READY", conn.read_line
    end
  end

  def test_read_line_raises_timeout_when_no_data
    make_conn("") do |conn|
      assert_raises(Prremote::TimeoutError) do
        conn.read_line(timeout: 0.01)
      end
    end
  end

  def test_write_bytes_sends_raw_data
    make_conn do |conn, fake|
      conn.write_bytes("hello".b)
      assert_includes fake.written, "hello".b
    end
  end

  def test_read_bytes_returns_exact_count
    make_conn("abcdef") do |conn|
      data = conn.read_bytes(3)
      assert_equal "abc", data
    end
  end

  def test_read_bytes_returns_empty_string_for_zero
    make_conn do |conn|
      assert_equal "".b, conn.read_bytes(0)
    end
  end

  def test_read_bytes_raises_timeout_when_insufficient_data
    make_conn("ab") do |conn|
      assert_raises(Prremote::TimeoutError) do
        conn.read_bytes(10, timeout: 0.01)
      end
    end
  end
end
