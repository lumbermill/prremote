require_relative 'test_helper'

class EsptoolTest < Minitest::Test
  def test_env_var_takes_precedence
    with_env('ESPTOOL' => '/bin/ls') do
      assert_equal '/bin/ls', Prremote::Esptool.bin
    end
  end

  def test_raises_when_not_found
    with_env('ESPTOOL' => nil, 'PATH' => '') do
      e = assert_raises(RuntimeError) { Prremote::Esptool.bin }
      assert_match(/esptool not found/, e.message)
    end
  end

  def test_write_flash_cmd_uses_dashes_for_v5
    Prremote::Esptool.stub(:version, '5.0.1') do
      assert_equal 'write-flash', Prremote::Esptool.write_flash_cmd
    end
  end

  def test_write_flash_cmd_uses_underscores_for_v4
    Prremote::Esptool.stub(:version, '4.8.1') do
      assert_equal 'write_flash', Prremote::Esptool.write_flash_cmd
    end
  end

  private

  def with_env(pairs)
    saved = pairs.keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    pairs.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
