require_relative "../test_helper"

class EvalCmdTest < Minitest::Test
  def test_delegates_to_eval_ruby
    conn = FakeConnection.new("3")
    Prremote::Commands::EvalCmd.new(conn).call("1 + 2")
    assert_equal ["1 + 2"], conn.eval_calls
  end

  def test_returns_eval_result
    conn = FakeConnection.new("42")
    result = Prremote::Commands::EvalCmd.new(conn).call("6 * 7")
    assert_equal "42", result
  end

  def test_empty_expression_returns_empty_string
    conn = FakeConnection.new("")
    assert_equal "", Prremote::Commands::EvalCmd.new(conn).call("")
  end
end
