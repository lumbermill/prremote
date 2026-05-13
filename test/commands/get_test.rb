require_relative "../test_helper"
require "tempfile"

class GetTest < Minitest::Test
  def call_get(content, remote: "/remote.rb")
    Tempfile.create("get_test") do |f|
      conn = FakeConnection.new
      conn.queue_line("SIZE #{content.bytesize}")
      conn.queue_bytes(content.b)
      Prremote::Commands::Get.new(conn).call(remote, f.path)
      yield conn, f.path if block_given?
      [conn, f.path]
    end
  end

  def test_sends_get_command_with_path
    Tempfile.create("get_test") do |f|
      conn = FakeConnection.new
      conn.queue_line("SIZE 0")
      conn.queue_bytes("".b)
      Prremote::Commands::Get.new(conn).call("/remote.rb", f.path)
      assert_equal "GET /remote.rb", conn.sent_lines.first
    end
  end

  def test_writes_correct_content_to_local_file
    content = "puts 'hello from pico'"
    Tempfile.create("get_test") do |f|
      conn = FakeConnection.new
      conn.queue_line("SIZE #{content.bytesize}")
      conn.queue_bytes(content.b)
      Prremote::Commands::Get.new(conn).call("/remote.rb", f.path)
      assert_equal content, File.binread(f.path)
    end
  end

  def test_handles_binary_content
    binary = (0..255).map(&:chr).join.b
    Tempfile.create(["get_test", ".bin"]) do |f|
      conn = FakeConnection.new
      conn.queue_line("SIZE #{binary.bytesize}")
      conn.queue_bytes(binary)
      Prremote::Commands::Get.new(conn).call("/bin.bin", f.path)
      assert_equal binary, File.binread(f.path)
    end
  end

  def test_raises_on_error_response
    Tempfile.create("get_test") do |f|
      conn = FakeConnection.new
      conn.queue_line("ERROR file not found")
      assert_raises(Prremote::ProtocolError) do
        Prremote::Commands::Get.new(conn).call("/missing.rb", f.path)
      end
    end
  end

  def test_raises_on_unexpected_response
    Tempfile.create("get_test") do |f|
      conn = FakeConnection.new
      conn.queue_line("UNKNOWN response")
      assert_raises(Prremote::ProtocolError) do
        Prremote::Commands::Get.new(conn).call("/r.rb", f.path)
      end
    end
  end
end
