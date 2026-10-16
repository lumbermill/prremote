require_relative 'test_helper'
require 'tmpdir'

class RuntimeManagerTest < Minitest::Test
  RM = Prremote::RuntimeManager

  def test_boards_include_pico2
    assert_includes RM::BOARDS, 'pico2'
    refute_includes RM::ESP32_BOARDS, 'pico2'
  end

  def test_pico2_artifact_is_uf2
    assert_equal 'prremote-pico2-runtime-0.3.2.uf2', RM.artifact_filename('0.3.2', 'pico2')
  end

  def test_esp32_artifact_is_bin
    assert_equal 'prremote-esp32c6-runtime-0.3.2.bin', RM.artifact_filename('0.3.2', 'esp32c6')
  end

  def test_pico2_release_url
    assert_equal 'https://github.com/lumbermill/prremote/releases/download/runtime-0.3.2/prremote-pico2-runtime-0.3.2.uf2',
                 RM.release_url('0.3.2', 'pico2')
  end

  def test_fetch_uses_cached_pico2_image
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'prremote-pico2-runtime-0.3.2.uf2')
      File.write(path, 'uf2')
      RM.stub(:cache_dir, dir) do
        RM.stub(:download, ->(*) { flunk 'should not download' }) do
          assert_equal path, RM.fetch('0.3.2', 'pico2')
        end
      end
    end
  end
end
