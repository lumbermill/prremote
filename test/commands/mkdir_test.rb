require_relative "../test_helper"

class MkdirTest < Minitest::Test
  def test_sends_mkdir_command
    conn = FakeConnection.new
    conn.queue_line("OK")
    Prremote::Commands::Mkdir.new(conn).call("/home/newdir")
    assert_equal "MKDIR /home/newdir", conn.sent_lines.first
  end

  def test_path_with_nested_directory
    conn = FakeConnection.new
    conn.queue_line("OK")
    Prremote::Commands::Mkdir.new(conn).call("/home/a/b")
    assert_equal "MKDIR /home/a/b", conn.sent_lines.first
  end

  def test_raises_on_error_response
    conn = FakeConnection.new
    conn.queue_line("ERROR already exists")
    assert_raises(Prremote::ProtocolError) do
      Prremote::Commands::Mkdir.new(conn).call("/existing")
    end
  end
end
