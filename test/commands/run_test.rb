require_relative "../test_helper"
require "tempfile"

class RunTest < Minitest::Test
  REMOTE_TMP = "/home/_prremote_run.rb"

  def setup
    @script = Tempfile.new(["run_test", ".rb"])
    @script.write("puts 'hi'")
    @script.flush
  end

  def teardown
    @script.close
    @script.unlink
  end

  # Put (small file) = 3 run calls, then load + File.delete = 2 more => 5 total
  def build_conn(responses = Array.new(5, ""))
    FakeConnection.new(*responses)
  end

  def test_uploads_script_to_remote_tmp
    conn = build_conn
    Prremote::Commands::Run.new(conn).call(@script.path)
    assert_includes conn.run_calls, %(load "#{REMOTE_TMP}")
  end

  def test_deletes_remote_tmp_after_run
    conn = build_conn
    Prremote::Commands::Run.new(conn).call(@script.path)
    assert_includes conn.run_calls, %(File.delete("#{REMOTE_TMP}"))
  end

  def test_returns_script_output
    # responses: open, write, close, load => "42", delete
    conn = build_conn(["", "", "", "42", ""])
    result = Prremote::Commands::Run.new(conn).call(@script.path)
    assert_equal "42", result
  end

  def test_custom_remote_tmp_path
    conn = build_conn
    Prremote::Commands::Run.new(conn).call(@script.path, remote_tmp: "/custom/tmp.rb")
    assert_includes conn.run_calls, %(load "/custom/tmp.rb")
  end
end
