require_relative "../test_helper"

class LsTest < Minitest::Test
  def make_conn(*lines)
    conn = FakeConnection.new
    lines.each { |l| conn.queue_line(l) }
    conn
  end

  def test_sends_ls_command_with_path
    conn = make_conn("END")
    Prremote::Commands::Ls.new(conn).call("/home")
    assert_equal "LS /home", conn.sent_lines.first
  end

  def test_default_path_is_slash
    conn = make_conn("END")
    Prremote::Commands::Ls.new(conn).call
    assert_equal "LS /", conn.sent_lines.first
  end

  def test_returns_array_of_filenames
    conn = make_conn("file1.rb", "file2.rb", "END")
    result = Prremote::Commands::Ls.new(conn).call("/")
    assert_equal ["file1.rb", "file2.rb"], result
  end

  def test_empty_directory_returns_empty_array
    conn = make_conn("END")
    assert_equal [], Prremote::Commands::Ls.new(conn).call("/")
  end

  def test_raises_on_error_response
    conn = make_conn("ERROR no such directory")
    assert_raises(Prremote::ProtocolError) do
      Prremote::Commands::Ls.new(conn).call("/missing")
    end
  end
end
