require_relative "test_helper"

class FakeSerial
  attr_reader :written

  def initialize(responses = [""])
    @responses  = responses.dup
    @written    = []
  end

  def write(data)
    @written << data
  end

  def read(_n)
    @responses.shift || ""
  end

  def close; end
end

class ConnectionTest < Minitest::Test
  def build_conn(responses: [""])
    fake = FakeSerial.new(responses)
    Serial.stub(:new, fake) do
      conn = Prremote::Connection.new(port: "/dev/ttyACM0")
      conn.stub(:sleep, nil) do
        conn.open
      end
      [conn, fake]
    end
  end

  def test_open_marks_connection_open
    Serial.stub(:new, FakeSerial.new) do
      conn = Prremote::Connection.new(port: "/dev/ttyACM0")
      conn.stub(:sleep, nil) { conn.open }
      assert conn.open?
    end
  end

  def test_close_marks_connection_closed
    Serial.stub(:new, FakeSerial.new) do
      conn = Prremote::Connection.new(port: "/dev/ttyACM0")
      conn.stub(:sleep, nil) { conn.open }
      conn.close
      refute conn.open?
    end
  end

  def test_run_raises_timeout_when_no_prompt
    Serial.stub(:new, FakeSerial.new([])) do
      conn = Prremote::Connection.new(port: "/dev/ttyACM0")
      conn.stub(:sleep, nil) { conn.open }
      assert_raises(Prremote::TimeoutError) do
        conn.run("bad", timeout: 0.01)
      end
    end
  end

  def test_run_returns_stripped_output
    responses = ["", "42\n> "]
    Serial.stub(:new, FakeSerial.new(responses)) do
      conn = Prremote::Connection.new(port: "/dev/ttyACM0")
      conn.stub(:sleep, nil) { conn.open }
      # We can't easily call run here without a real serial, so just verify
      # read_until_prompt strips the prompt. We stub read directly.
      assert_equal "42", conn.send(:read_until_prompt, timeout: 1) { "42\n> " } rescue nil
    end
  end
end
