require_relative "../test_helper"

class EvalCmdTest < Minitest::Test
  def test_sends_eval_command
    conn = FakeConnection.new
    conn.queue_line("OK 42")
    Prremote::Commands::EvalCmd.new(conn).call("6 * 7")
    assert_equal "EVAL 6 * 7", conn.sent_lines.first
  end

  def test_returns_result_without_ok_prefix
    conn = FakeConnection.new
    conn.queue_line("OK 42")
    result = Prremote::Commands::EvalCmd.new(conn).call("6 * 7")
    assert_equal "42", result
  end

  def test_raises_on_error_response
    conn = FakeConnection.new
    conn.queue_line("ERROR undefined method 'foo'")
    assert_raises(Prremote::ProtocolError) do
      Prremote::Commands::EvalCmd.new(conn).call("foo")
    end
  end

  def test_empty_result_returns_empty_string
    conn = FakeConnection.new
    conn.queue_line("OK ")
    result = Prremote::Commands::EvalCmd.new(conn).call("nil")
    assert_equal "", result
  end
end
