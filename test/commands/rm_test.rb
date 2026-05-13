require_relative "../test_helper"

class RmTest < Minitest::Test
  def test_sends_rm_command
    conn = FakeConnection.new
    conn.queue_line("OK")
    Prremote::Commands::Rm.new(conn).call("/home/app.rb")
    assert_equal "RM /home/app.rb", conn.sent_lines.first
  end

  def test_path_with_nested_directory
    conn = FakeConnection.new
    conn.queue_line("OK")
    Prremote::Commands::Rm.new(conn).call("/home/subdir/app.rb")
    assert_equal "RM /home/subdir/app.rb", conn.sent_lines.first
  end

  def test_raises_on_error_response
    conn = FakeConnection.new
    conn.queue_line("ERROR file not found")
    assert_raises(Prremote::ProtocolError) do
      Prremote::Commands::Rm.new(conn).call("/missing.rb")
    end
  end
end
