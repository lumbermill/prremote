require_relative "test_helper"
require "tempfile"

# These tests require a PicoRuby/R2P2 device connected via USB.
# If no device is found, all tests are skipped with instructions.
#
# NOTE: If ALL tests fail with TimeoutError in setup, the device is frozen.
# Physically reset the Pico (unplug/replug USB or press the reset button)
# and re-run: bundle exec rake integration
class IntegrationTest < Minitest::Test
  SKIP_MSG = <<~MSG.freeze

    ─── 実機テストをスキップしました ────────────────────────────────
    Pico (R2P2) が見つかりません。
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

  def test_ls_root_returns_array
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
      assert_equal content, File.read(dst.path)
    end
  ensure
    @conn.run(%(File.delete("#{remote}"))) rescue nil
  end

  def test_mkdir_creates_directory_and_rm_removes_file
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
    @conn.run(%(File.delete("#{file}"))) rescue nil
  end

  def test_run_executes_script_and_returns_output
    Tempfile.create(["run_src", ".rb"]) do |f|
      f.write("puts 42")
      f.flush
      result = Prremote::Commands::Run.new(@conn).call(f.path)
      assert_match(/42/, result)
    end
  end
end
