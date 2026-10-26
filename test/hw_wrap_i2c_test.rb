require_relative 'test_helper'

# Loads the runtime's I2C class (runtime/src/hw_wrap.rb) into CRuby with the
# C bindings replaced by a fake bus, to pin down the Ruby-side contract.
class HwWrapI2CTest < Minitest::Test
  HW_WRAP = File.expand_path('../runtime/src/hw_wrap.rb', __dir__)

  # Records binding calls; addresses in `present` ACK a probe.
  class FakeBus
    attr_reader :calls

    def initialize(present)
      @present = present
      @calls = []
    end

    def _i2c_init(unit, _freq, _sda, _scl) = unit

    def _i2c_probe(unit, addr, timeout) # rubocop:disable Naming/PredicateMethod -- mirrors the C binding's name
      @calls << [:probe, unit, addr, timeout]
      @present.include?(addr)
    end

    def _i2c_read(unit, addr, len, timeout)
      @calls << [:read, unit, addr, len, timeout]
      nil
    end

    def _i2c_write(unit, addr, data, nostop, timeout)
      @calls << [:write, unit, addr, data, nostop, timeout]
      data.size
    end
  end

  def setup
    @mod = Module.new
    @mod.module_eval(File.read(HW_WRAP), HW_WRAP)
  end

  def i2c_on(bus, **opts)
    i2c_class = @mod.const_get(:I2C)
    klass = Class.new(i2c_class)
    %i[_i2c_init _i2c_probe _i2c_read _i2c_write].each do |name|
      klass.define_method(name) { |*args| bus.public_send(name, *args) }
    end
    klass.new(**opts)
  end

  def test_scan_returns_acking_addresses
    bus = FakeBus.new([0x3e, 0x48])
    assert_equal [0x3e, 0x48], i2c_on(bus, sda_pin: 4, scl_pin: 5).scan
  end

  # A read probe is what jams write-only parts such as ST7032 LCDs.
  def test_scan_probes_with_address_only_writes_never_reads
    bus = FakeBus.new([0x3e])
    i2c_on(bus).scan

    kinds = bus.calls.map(&:first).uniq
    assert_equal [:probe], kinds
    assert_equal((0x08..0x77).to_a, bus.calls.map { |c| c[2] })
  end

  def test_scan_yields_each_address_with_result
    bus = FakeBus.new([0x48])
    seen = []
    found = i2c_on(bus).scan { |addr, ok| seen << [addr, ok] }

    assert_equal 112, seen.size
    assert_equal [0x08, false], seen.first
    assert_includes seen, [0x48, true]
    assert_equal [0x48], found
  end

  def test_scan_uses_instance_timeout_by_default
    bus = FakeBus.new([])
    i2c_on(bus, timeout: 123).scan
    assert(bus.calls.all? { |c| c[3] == 123 })
  end

  def test_scan_timeout_keyword_overrides_instance_timeout
    bus = FakeBus.new([])
    i2c_on(bus, timeout: 123).scan(timeout: 20)
    assert(bus.calls.all? { |c| c[3] == 20 })
  end

  def test_read_and_write_pass_timeout
    bus = FakeBus.new([])
    i2c = i2c_on(bus, timeout: 50)
    i2c.write(0x3e, 0x00, 0x38)
    i2c.read(0x48, 2, 0x00)

    assert_equal [:write, 0, 0x3e, [0x00, 0x38], 0, 50], bus.calls[0]
    assert_equal [:write, 0, 0x48, [0x00], 1, 50], bus.calls[1]
    assert_equal [:read, 0, 0x48, 2, 50], bus.calls[2]
  end
end
