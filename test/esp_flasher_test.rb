require_relative 'test_helper'

# Serial stand-in: records writes, replays scripted reads.
class FakeSerialFlasher
  attr_reader :written

  def initialize(responses = [])
    @responses = responses.dup
    @written   = []
  end

  def write(data) = @written << data
  def read(_len)  = @responses.shift || ''
  def close       = nil
end

class EspFlasherTest < Minitest::Test
  # Builds a SLIP-framed ROM-loader response for the given op.
  def response(op, value: 0, data: ''.b, status: "\x00\x00\x00\x00".b)
    body   = data + status
    packet = [0x01, op, body.bytesize].pack('CCv') + [value].pack('V') + body
    flasher.slip_encode(packet)
  end

  def flasher(serial = FakeSerialFlasher.new)
    Prremote::EspFlasher.new(serial)
  end

  def test_slip_roundtrip_escapes_markers
    f = flasher
    raw = "\x01\xC0\x02\xDB\x03".b
    assert_equal raw, f.slip_decode(f.slip_encode(raw).byteslice(1..-2))
  end

  def test_checksum_is_xor_seeded_with_0xef
    assert_equal 0xEF ^ 0x12 ^ 0x34, flasher.checksum("\x12\x34".b)
  end

  def test_command_returns_value_and_strips_status
    serial = FakeSerialFlasher.new
    f      = Prremote::EspFlasher.new(serial)
    serial.instance_variable_get(:@responses) <<
      response(0x13, value: 7, data: 'abcd'.b)

    value, data = f.command(0x13, ''.b, timeout: 1)
    assert_equal 7, value
    assert_equal 'abcd', data
    # request framing: C0 <00> <op> ... C0
    req = serial.written.first
    assert_equal 0xC0, req.getbyte(0)
    assert_equal 0x00, req.getbyte(1)
    assert_equal 0x13, req.getbyte(2)
  end

  def test_command_raises_on_error_status
    serial = FakeSerialFlasher.new
    f      = Prremote::EspFlasher.new(serial)
    serial.instance_variable_get(:@responses) <<
      response(0x02, status: "\x01\x05\x00\x00".b)

    e = assert_raises(Prremote::EspFlasher::Error) { f.command(0x02, ''.b, timeout: 1) }
    assert_match(/error 0x05/, e.message)
  end

  def test_command_times_out_without_response
    f = flasher
    e = assert_raises(Prremote::EspFlasher::Error) { f.command(0x08, ''.b, timeout: 0.05) }
    assert_match(/timeout/, e.message)
  end

  def test_command_skips_foreign_frames
    serial = FakeSerialFlasher.new
    f      = Prremote::EspFlasher.new(serial)
    serial.instance_variable_get(:@responses).push(
      response(0x08), # stale sync response
      response(0x13, data: 'ok'.b)
    )

    _value, data = f.command(0x13, ''.b, timeout: 1)
    assert_equal 'ok', data
  end

  def test_verify_md5_accepts_matching_digest
    image  = 'hello world'.b
    serial = FakeSerialFlasher.new
    f      = Prremote::EspFlasher.new(serial)
    serial.instance_variable_get(:@responses) <<
      response(0x13, data: Digest::MD5.hexdigest(image).b)

    f.verify_md5(image) # must not raise
  end

  def test_verify_md5_raises_on_mismatch
    serial = FakeSerialFlasher.new
    f      = Prremote::EspFlasher.new(serial)
    serial.instance_variable_get(:@responses) <<
      response(0x13, data: ('0' * 32).b)

    assert_raises(Prremote::EspFlasher::Error) { f.verify_md5('hello'.b) }
  end
end
