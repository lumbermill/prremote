require_relative '../test_helper'
require 'tmpdir'

class InstallTest < Minitest::Test
  def setup
    @install = Prremote::Commands::Install.new(board: 'picow')
  end

  # Stands in for a BOOTSEL volume, with INFO_UF2.TXT as an RP2040 writes it.
  def with_bootsel_volume(board_id: 'RPI-RP2')
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, Prremote::Commands::Install::BOOTSEL_MARKER),
                 "UF2 Bootloader v3.0\nModel: Raspberry Pi RP2\nBoard-ID: #{board_id}\n")
      yield dir
    end
  end

  def test_drive_letter_roots_cover_wsl_mount_points
    roots = @install.send(:drive_letter_roots)

    assert_includes roots, '/mnt/d'
    assert_includes roots, '/mnt/z'
    refute(roots.any? { |root| root.match?(/\A[A-Z]:/) })
  end

  # /mnt/c is the Windows system drive under WSL.
  def test_drive_letter_roots_skip_the_system_drive
    refute_includes @install.send(:drive_letter_roots), '/mnt/c'
  end

  def test_drive_letter_volume_paths_finds_volume_by_marker
    with_bootsel_volume do |dir|
      @install.stub(:drive_letter_roots, [dir]) do
        assert_equal [dir], @install.send(:drive_letter_volume_paths)
      end
    end
  end

  def test_drive_letter_volume_paths_ignores_drives_without_marker
    Dir.mktmpdir do |dir|
      @install.stub(:drive_letter_roots, [dir]) do
        assert_empty @install.send(:drive_letter_volume_paths)
      end
    end
  end

  # RP2350 and other UF2 bootloaders expose INFO_UF2.TXT as well.
  def test_drive_letter_volume_paths_ignores_other_uf2_bootloaders
    with_bootsel_volume(board_id: 'RP2350') do |dir|
      @install.stub(:drive_letter_roots, [dir]) do
        assert_empty @install.send(:drive_letter_volume_paths)
      end
    end
  end

  def test_drive_letter_volume_paths_ignores_missing_roots
    @install.stub(:drive_letter_roots, ['/nonexistent-drive-root']) do
      assert_empty @install.send(:drive_letter_volume_paths)
    end
  end

  def test_volume_paths_keeps_unix_candidates
    @install.stub(:drive_letter_roots, []) do
      assert_includes @install.send(:volume_paths), '/Volumes/RPI-RP2'
    end
  end

  def test_volume_paths_appends_drive_letter_volume
    with_bootsel_volume do |dir|
      @install.stub(:drive_letter_roots, [dir]) do
        paths = @install.send(:volume_paths)

        assert_includes paths, '/Volumes/RPI-RP2'
        assert_includes paths, dir
      end
    end
  end

  def test_wait_for_volume_returns_drive_letter_volume
    with_bootsel_volume do |dir|
      @install.stub(:drive_letter_roots, [dir]) do
        assert_equal dir, @install.send(:wait_for_volume, timeout: 1)
      end
    end
  end

  def test_mounted_is_true_while_marker_present
    with_bootsel_volume do |dir|
      assert @install.send(:mounted?, dir)
    end
  end

  # The board reboots on write, so the marker goes away even where the WSL
  # mountpoint directory itself lingers.
  def test_mounted_is_false_once_marker_is_gone
    Dir.mktmpdir do |dir|
      refute @install.send(:mounted?, dir)
    end
  end

  def test_wait_for_unmount_returns_when_marker_disappears
    Dir.mktmpdir do |dir|
      @install.send(:wait_for_unmount, dir, timeout: 1)
    end
  end

  def test_wait_for_unmount_times_out_while_volume_is_present
    with_bootsel_volume do |dir|
      error = assert_raises(RuntimeError) do
        @install.send(:wait_for_unmount, dir, timeout: 0)
      end
      assert_match(/Timed out waiting for device to reboot/, error.message)
    end
  end

  def test_pico2_waits_for_rp2350_volume
    install = Prremote::Commands::Install.new(board: 'pico2')
    install.stub(:drive_letter_roots, []) do
      paths = install.send(:volume_paths)
      assert_includes paths, '/Volumes/RP2350'
      assert(paths.all? { |p| p.end_with?('/RP2350') })
    end
  end

  def test_rp2040_boards_wait_for_rpi_rp2_volume
    %w[pico picow].each do |board|
      install = Prremote::Commands::Install.new(board: board)
      install.stub(:drive_letter_roots, []) do
        paths = install.send(:volume_paths)
        assert_includes paths, '/Volumes/RPI-RP2'
        assert(paths.all? { |p| p.end_with?('/RPI-RP2') })
      end
    end
  end

  # Under WSL, pico2 must pick the RP2350 drive and skip an RP2040 one.
  def test_pico2_drive_letter_volume_matches_rp2350_board_id
    install = Prremote::Commands::Install.new(board: 'pico2')
    with_bootsel_volume(board_id: 'RP2350') do |rp2350|
      with_bootsel_volume do |rp2040|
        install.stub(:drive_letter_roots, [rp2040, rp2350]) do
          assert_equal [rp2350], install.send(:drive_letter_volume_paths)
        end
      end
    end
  end

  def test_pico2_copies_uf2_to_rp2350_volume
    Dir.mktmpdir do |dir|
      uf2 = File.join(dir, 'prremote-pico2-runtime-0.3.2.uf2')
      File.write(uf2, 'uf2')
      volume = File.join(dir, 'RP2350')
      Dir.mkdir(volume)
      cmd = Prremote::Commands::Install.new(version: '0.3.2', board: 'pico2')

      out, err = capture_io do
        Prremote::RuntimeManager.stub(:fetch, uf2) do
          cmd.stub(:volume_paths, [volume]) do
            cmd.stub(:wait_for_unmount, nil) { cmd.call }
          end
        end
      end

      assert File.exist?(File.join(volume, File.basename(uf2)))
      assert_match(/Put the Pico 2 into BOOTSEL mode/, out)
      assert_match(/Waiting for RP2350\.\.\./, out)
      assert_match(/not been verified on real hardware/, err)
    end
  end

  def test_rp2040_install_prints_no_unverified_note
    _, err = capture_io { Prremote::Commands::Install.new(board: 'picow').send(:warn_unverified) }
    assert_empty err
  end
end
