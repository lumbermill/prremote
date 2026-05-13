require_relative "test_helper"
require "tempfile"

# These tests require a Pico running prremote-agent firmware connected via USB.
# If no device is found, all tests are skipped.
#
# Run with: bundle exec rake integration
class IntegrationTest < Minitest::Test
  SKIP_MSG = <<~MSG.freeze

    ─── 実機テストをスキップしました ────────────────────────────────
    prremote-agent を書き込んだ Pico が見つかりません。
    USB に接続してから再実行してください:

      bundle exec rake integration

    ─────────────────────────────────────────────────────────────────
  MSG

  def setup
    port = Prremote::Detector.find_device
    skip SKIP_MSG unless port
    @conn = Prremote::Connection.new(port: port).open
  end

  def teardown
    @conn&.close
  rescue StandardError
    nil
  end

  def test_ls_returns_array
    result = Prremote::Commands::Ls.new(@conn).call("/")
    assert_kind_of Array, result
  end

  def test_eval_arithmetic
    result = Prremote::Commands::EvalCmd.new(@conn).call("1 + 1")
    assert_equal "2", result
  end

  def test_put_and_get_roundtrip
    content = "puts 'roundtrip test'"
    remote  = "/home/_prremote_test_rtrip.rb"

    Tempfile.create(["put_src", ".rb"]) do |src|
      src.write(content)
      src.flush
      Prremote::Commands::Put.new(@conn).call(src.path, remote)
    end

    Tempfile.create(["get_dst", ".rb"]) do |dst|
      Prremote::Commands::Get.new(@conn).call(remote, dst.path)
      assert_equal content, File.binread(dst.path)
    end
  ensure
    Prremote::Commands::Rm.new(@conn).call(remote) rescue nil
  end

  def test_mkdir_and_rm
    dir  = "/home/_prremote_testdir"
    file = "#{dir}/test.rb"

    Prremote::Commands::Mkdir.new(@conn).call(dir)

    Tempfile.create(["rm_src", ".rb"]) do |src|
      src.write("x")
      src.flush
      Prremote::Commands::Put.new(@conn).call(src.path, file)
    end

    Prremote::Commands::Rm.new(@conn).call(file)
    ls = Prremote::Commands::Ls.new(@conn).call(dir)
    refute_includes ls, "test.rb"
  ensure
    Prremote::Commands::Rm.new(@conn).call(file) rescue nil
  end
end
