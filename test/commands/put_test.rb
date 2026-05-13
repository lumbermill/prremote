require_relative "../test_helper"
require "tempfile"

class PutTest < Minitest::Test
  def call_put(content, remote: "/remote.rb")
    Tempfile.create(["put_test", ".rb"]) do |f|
      f.binmode
      f.write(content)
      f.flush
      conn = FakeConnection.new
      conn.queue_line("READY")
      conn.queue_line("OK")
      yield conn, f.path if block_given?
      Prremote::Commands::Put.new(conn).call(f.path, remote)
      conn
    end
  end

  def test_sends_put_command_with_path_and_size
    conn = call_put("hello")
    assert_equal "PUT /remote.rb 5", conn.sent_lines.first
  end

  def test_sends_file_content_as_bytes
    content = "puts 'hi'"
    conn = call_put(content)
    assert_equal content, conn.sent_bytes.first
  end

  def test_remote_path_in_put_command
    Tempfile.create(["put_test", ".rb"]) do |f|
      f.write("x")
      f.flush
      conn = FakeConnection.new
      conn.queue_line("READY")
      conn.queue_line("OK")
      Prremote::Commands::Put.new(conn).call(f.path, "/foo/bar.rb")
      assert_includes conn.sent_lines.first, "/foo/bar.rb"
    end
  end

  def test_raises_protocol_error_when_not_ready
    Tempfile.create("put_test") do |f|
      f.write("x")
      f.flush
      conn = FakeConnection.new
      conn.queue_line("ERROR busy")
      assert_raises(Prremote::ProtocolError) do
        Prremote::Commands::Put.new(conn).call(f.path, "/r.rb")
      end
    end
  end

  def test_raises_protocol_error_on_error_after_write
    Tempfile.create("put_test") do |f|
      f.write("x")
      f.flush
      conn = FakeConnection.new
      conn.queue_line("READY")
      conn.queue_line("ERROR out of memory")
      assert_raises(Prremote::ProtocolError) do
        Prremote::Commands::Put.new(conn).call(f.path, "/r.rb")
      end
    end
  end

  def test_binary_content_sent_verbatim
    binary = (0..255).map(&:chr).join
    conn = call_put(binary)
    assert_equal binary, conn.sent_bytes.first
  end
end
