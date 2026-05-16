require_relative "../test_helper"

class RunCommandTest < Minitest::Test
  def test_raises_when_file_not_found
    cmd = Prremote::Commands::Run.new(port: "/dev/null", baud: 115_200)
    err = assert_raises(RuntimeError) { cmd.call("/nonexistent/path.rb") }
    assert_match(/File not found/, err.message)
  end
end

class DeployCommandTest < Minitest::Test
  def test_raises_when_file_not_found
    cmd = Prremote::Commands::Deploy.new(port: "/dev/null", baud: 115_200)
    err = assert_raises(RuntimeError) { cmd.call("/nonexistent/path.rb") }
    assert_match(/File not found/, err.message)
  end
end
