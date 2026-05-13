require_relative "test_helper"

class FakeSerial
  attr_reader :written

  def initialize(responses = [""])
    @responses = responses.dup
    @written   = []
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
  # open() now does two read(4096) calls (boot noise + Ctrl-C drain) then
  # reads until "$> " in a loop.
  OPEN_SEQ = ["", "", "$> "].freeze

  def open_conn(extra_responses: [])
    fake = FakeSerial.new(OPEN_SEQ + extra_responses)
    Serial.stub(:new, fake) do
      conn = Prremote::Connection.new(port: "/dev/ttyACM0")
      conn.stub(:sleep, nil) { conn.open }
      yield conn, fake
    end
  end

  def test_open_marks_connection_open
    open_conn { |conn| assert conn.open? }
  end

  def test_close_marks_connection_closed
    open_conn do |conn|
      conn.close
      refute conn.open?
    end
  end

  def test_run_raises_timeout_when_no_prompt
    # After open, the queue is empty so run() times out immediately.
    open_conn do |conn|
      assert_raises(Prremote::TimeoutError) do
        conn.run("bad", timeout: 0.01)
      end
    end
  end

  def test_run_returns_stripped_output
    # Serial echoes the command then prints output followed by prompt.
    run_response = "echo\r\n42\n$> "
    open_conn(extra_responses: [run_response]) do |conn|
      assert_equal "42", conn.run("echo")
    end
  end
end
