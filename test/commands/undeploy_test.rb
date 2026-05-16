require_relative "../test_helper"

class FakeSerialErase
  attr_reader :written

  def initialize(responses = [])
    @responses = responses.dup
    @written   = []
  end

  def write(data) = @written << data
  def read(_n)    = @responses.shift || ""
  def close       = nil
end

class UndeployCommandTest < Minitest::Test
  def test_sends_erse_magic
    fake = FakeSerialErase.new(["", "ERASED\n"])
    cmd  = Prremote::Commands::Undeploy.new(port: "/dev/null", baud: 115_200)

    Serial.stub(:new, fake) do
      cmd.stub(:sleep, nil) { cmd.call }
    end

    assert_includes fake.written, "ERSE"
  end

  def test_raises_on_timeout
    fake = FakeSerialErase.new
    cmd  = Prremote::Commands::Undeploy.new(port: "/dev/null", baud: 115_200)

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
end
