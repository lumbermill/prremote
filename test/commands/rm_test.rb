require_relative "../test_helper"

class RmTest < Minitest::Test
  def test_sends_file_delete_command
    conn = FakeConnection.new
    Prremote::Commands::Rm.new(conn).call("/foo.rb")
    assert_equal [%(File.delete("/foo.rb"))], conn.run_calls
  end

  def test_path_with_parent_directory
    conn = FakeConnection.new
    Prremote::Commands::Rm.new(conn).call("/home/app.rb")
    assert_equal [%(File.delete("/home/app.rb"))], conn.run_calls
  end

  def test_only_one_run_call
    conn = FakeConnection.new
    Prremote::Commands::Rm.new(conn).call("/x.rb")
    assert_equal 1, conn.run_calls.size
  end
end
