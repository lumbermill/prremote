require_relative '../test_helper'

class FakeSerialLs
  attr_reader :written

  def initialize(responses = [])
    @responses = responses.dup
    @written   = []
  end

  def write(data) = @written << data
  def read(_len)  = @responses.shift || ''
  def close       = nil
end

class LsCommandTest < Minitest::Test
  def test_shows_deployed_script
    ts   = 1_716_729_296
    fake = FakeSerialLs.new(['READY prremote-runtime/0.1.5\n', "DEPLOYED #{ts} lib.rb app.rb\n"])
    cmd  = Prremote::Commands::Ls.new(port: '/dev/null', baud: 115_200)

    out = capture_io do
      Serial.stub(:new, fake) do
        cmd.stub(:sleep, nil) { cmd.call }
      end
    end.first

    assert_equal ["\x03", 'QURY'], fake.written
    assert_match(/Files:\s+lib\.rb app\.rb/, out)
    assert_match(/Deployed:\s+\d{4}-\d{2}-\d{2}/, out)
  end

  def test_shows_no_script_when_none
    fake = FakeSerialLs.new(['READY prremote-runtime/0.1.5\n', "NONE\n"])
    cmd  = Prremote::Commands::Ls.new(port: '/dev/null', baud: 115_200)

    out = capture_io do
      Serial.stub(:new, fake) do
        cmd.stub(:sleep, nil) { cmd.call }
      end
    end.first

    assert_match(/No script deployed/, out)
  end

  def test_raises_on_timeout
    fake = FakeSerialLs.new
    cmd  = Prremote::Commands::Ls.new(port: '/dev/null', baud: 115_200)

    Serial.stub(:new, fake) do
      cmd.stub(:sleep, nil) do
        base  = Time.now
        count = 0
        stub_now = -> { (count += 1) <= 1 ? base : base + 60 }
        Time.stub(:now, stub_now) do
          err = assert_raises(RuntimeError) { cmd.call }
          assert_match(/Timeout/, err.message)
        end
      end
    end
  end

  def test_shows_unknown_timestamp_when_zero
    fake = FakeSerialLs.new(['READY prremote-runtime/0.1.5\n', "DEPLOYED 0 app.rb\n"])
    cmd  = Prremote::Commands::Ls.new(port: '/dev/null', baud: 115_200)

    out = capture_io do
      Serial.stub(:new, fake) do
        cmd.stub(:sleep, nil) { cmd.call }
      end
    end.first

    assert_match(/\(unknown\)/, out)
  end
end
