require_relative '../test_helper'
require 'tmpdir'

class InstallCommandTest < Minitest::Test
  def install(board)
    Prremote::Commands::Install.new(version: '0.3.2', board: board)
  end

  def test_pico2_waits_for_rp2350_volume
    paths = install('pico2').send(:volume_paths)
    assert_includes paths, '/Volumes/RP2350'
    assert(paths.all? { |p| p.end_with?('/RP2350') })
  end

  def test_rp2040_boards_wait_for_rpi_rp2_volume
    %w[pico picow].each do |board|
      paths = install(board).send(:volume_paths)
      assert_includes paths, '/Volumes/RPI-RP2'
      assert(paths.all? { |p| p.end_with?('/RPI-RP2') })
    end
  end

  def test_pico2_copies_uf2_to_rp2350_volume
    Dir.mktmpdir do |dir|
      uf2 = File.join(dir, 'prremote-pico2-runtime-0.3.2.uf2')
      File.write(uf2, 'uf2')
      volume = File.join(dir, 'RP2350')
      Dir.mkdir(volume)
      cmd = install('pico2')

      out, = capture_io do
        Prremote::RuntimeManager.stub(:fetch, uf2) do
          cmd.stub(:volume_paths, [volume]) do
            cmd.stub(:wait_for_unmount, nil) { cmd.call }
          end
        end
      end

      assert File.exist?(File.join(volume, File.basename(uf2)))
      assert_match(/Put the Pico 2 into BOOTSEL mode/, out)
      assert_match(/Waiting for RP2350\.\.\./, out)
    end
  end
end
