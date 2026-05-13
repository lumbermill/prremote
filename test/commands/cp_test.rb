require_relative "../test_helper"

class CpTest < Minitest::Test
  def test_sends_cp_command
    conn = FakeConnection.new
    conn.queue_line("OK")
    Prremote::Commands::Cp.new(conn).call("/src.rb", "/dst.rb")
    assert_equal "CP /src.rb /dst.rb", conn.sent_lines.first
  end

  def test_raises_on_error_response
    conn = FakeConnection.new
    conn.queue_line("ERROR file not found")
    assert_raises(Prremote::ProtocolError) do
      Prremote::Commands::Cp.new(conn).call("/missing.rb", "/dst.rb")
    end
  end
end
