require_relative "../test_helper"

class MkdirTest < Minitest::Test
  def test_sends_dir_mkdir_command
    conn = FakeConnection.new
    Prremote::Commands::Mkdir.new(conn).call("/newdir")
    assert_equal [%(Dir.mkdir("/newdir"))], conn.run_calls
  end

  def test_path_with_parent_directory
    conn = FakeConnection.new
    Prremote::Commands::Mkdir.new(conn).call("/home/subdir")
    assert_equal [%(Dir.mkdir("/home/subdir"))], conn.run_calls
  end

  def test_only_one_run_call
    conn = FakeConnection.new
    Prremote::Commands::Mkdir.new(conn).call("/d")
    assert_equal 1, conn.run_calls.size
  end
end
