require_relative '../test_helper'

class SerialHelpersTest < Minitest::Test
  include Prremote::Commands::SerialHelpers

  def test_no_warning_when_versions_match
    buf = "READY prremote-runtime/#{Prremote::VERSION}\n"
    out = capture_io { send(:warn_if_runtime_outdated, buf) }
    assert_empty out[1]
  end

  def test_no_warning_when_runtime_is_newer
    newer = bump_patch(Prremote::VERSION)
    buf = "READY prremote-runtime/#{newer}\n"
    out = capture_io { send(:warn_if_runtime_outdated, buf) }
    assert_empty out[1]
  end

  def test_warns_when_runtime_is_older
    older = older_version(Prremote::VERSION)
    buf = "READY prremote-runtime/#{older}\n"
    out = capture_io { send(:warn_if_runtime_outdated, buf) }
    assert_match(/Warning:.*runtime.*#{Regexp.escape(older)}.*prremote install/i, out[1])
  end

  def test_no_warning_when_no_version_in_ready
    out = capture_io { send(:warn_if_runtime_outdated, "READY \n") }
    assert_empty out[1]
  end

  def test_no_crash_on_unparseable_version
    buf = "READY prremote-runtime/dev-build\n"
    assert_silent { send(:warn_if_runtime_outdated, buf) }
  end

  private

  def bump_patch(version)
    parts = version.split('.')
    parts[-1] = (parts[-1].to_i + 1).to_s
    parts.join('.')
  end

  def older_version(version)
    parts = version.split('.')
    patch = parts[-1].to_i
    if patch > 0
      parts[-1] = (patch - 1).to_s
    else
      parts[-2] = (parts[-2].to_i - 1).to_s
    end
    parts.join('.')
  end
end
