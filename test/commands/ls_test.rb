require_relative "../test_helper"

class LsTest < Minitest::Test
  def test_sends_ls_command_with_path
    conn = FakeConnection.new("")
    Prremote::Commands::Ls.new(conn).call("/home")
    assert_equal ["ls /home"], conn.run_calls
  end

  def test_default_path_is_slash
    conn = FakeConnection.new("")
    Prremote::Commands::Ls.new(conn).call
    assert_equal ["ls /"], conn.run_calls
  end

  def test_returns_array_of_filenames
    conn = FakeConnection.new("file1.rb\nfile2.rb\n")
    result = Prremote::Commands::Ls.new(conn).call("/")
    assert_equal ["file1.rb", "file2.rb"], result
  end

  def test_empty_output_returns_empty_array
    conn = FakeConnection.new("")
    assert_equal [], Prremote::Commands::Ls.new(conn).call("/")
  end

  def test_blank_lines_are_stripped
    conn = FakeConnection.new("file1.rb\n\n\nfile2.rb\n")
    assert_equal ["file1.rb", "file2.rb"], Prremote::Commands::Ls.new(conn).call("/")
  end
end
