require_relative "../test_helper"
require "tempfile"
require "base64"

class PutTest < Minitest::Test
  CHUNK = Prremote::Commands::Put::CHUNK_SIZE

  def call_put(content, remote: "/remote.rb")
    Tempfile.create(["put_test", ".rb"]) do |f|
      f.binmode
      f.write(content)
      f.flush
      conn = FakeConnection.new
      Prremote::Commands::Put.new(conn).call(f.path, remote)
      conn
    end
  end

  def test_first_call_requires_base64_and_opens_file
    conn = call_put("puts 'hello'")
    assert_match(/require "base64"/, conn.run_calls.first)
    assert_match(/File\.open.*"\/remote\.rb"/, conn.run_calls.first)
  end

  def test_last_call_closes_file
    conn = call_put("puts 'hello'")
    assert_equal "f.close", conn.run_calls.last
  end

  def test_small_file_uses_one_write_chunk
    conn = call_put("x" * 10)
    assert_equal 3, conn.run_calls.size  # open + 1 write + close
  end

  def test_large_file_uses_multiple_chunks
    conn = call_put("x" * (CHUNK * 2 + 1))
    assert_equal 5, conn.run_calls.size  # open + 3 writes + close
  end

  def test_write_chunk_uses_base64_decode
    conn = call_put("hello")
    assert_match(/f\.write\(Base64\.decode64\(/, conn.run_calls[1])
  end

  def test_remote_path_in_open_call
    conn = call_put("data", remote: "/foo/bar.rb")
    assert_includes conn.run_calls.first, "/foo/bar.rb"
  end

  def test_write_chunk_content_roundtrips
    content = "hello"
    conn = call_put(content)
    b64 = conn.run_calls[1][/decode64\("([^"]+)"\)/, 1]
    assert_equal content, Base64.strict_decode64(b64)
  end
end
