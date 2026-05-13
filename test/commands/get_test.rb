require_relative "../test_helper"
require "tempfile"
require "base64"

class GetTest < Minitest::Test
  def test_requires_base64_first
    conn = FakeConnection.new("", Base64.encode64(""))
    Tempfile.create("get_test") do |f|
      Prremote::Commands::Get.new(conn).call("/remote.rb", f.path)
    end
    assert_equal 'require "base64"', conn.run_calls.first
  end

  def test_sends_base64_read_command
    conn = FakeConnection.new("", Base64.encode64(""))
    Tempfile.create("get_test") do |f|
      Prremote::Commands::Get.new(conn).call("/remote.rb", f.path)
    end
    assert_match(/Base64\.encode64/, conn.run_calls.last)
    assert_match(%r{/remote\.rb}, conn.run_calls.last)
  end

  def test_writes_decoded_content_to_local_file
    content = "puts 'hello from pico'"
    conn = FakeConnection.new("", Base64.encode64(content))
    Tempfile.create("get_test") do |f|
      Prremote::Commands::Get.new(conn).call("/remote.rb", f.path)
      assert_equal content, File.binread(f.path)
    end
  end

  def test_handles_binary_content
    binary = (0..255).map(&:chr).join
    conn = FakeConnection.new("", Base64.encode64(binary))
    Tempfile.create(["get_test", ".bin"]) do |f|
      Prremote::Commands::Get.new(conn).call("/remote.bin", f.path)
      assert_equal binary, File.binread(f.path)
    end
  end
end
