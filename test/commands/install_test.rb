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

  # An empty mountpoint left behind after a reboot is not a BOOTSEL drive.
  def test_wait_for_volume_ignores_directory_without_marker
    Dir.mktmpdir do |dir|
      @install.stub(:volume_paths, [dir]) do
        assert_raises(RuntimeError) { @install.send(:wait_for_volume, timeout: 0) }
        capture_io { assert_nil @install.send(:mounted_volume) }
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
      File.write(File.join(volume, Prremote::Commands::Install::BOOTSEL_MARKER), "Board-ID: RP2350\n")
      cmd = Prremote::Commands::Install.new(version: '0.3.2', board: 'pico2')

      out, err = capture_io do
        Prremote::RuntimeManager.stub(:fetch, uf2) do
          cmd.stub(:volume_paths, [volume]) do
            cmd.stub(:wait_for_unmount, nil) { cmd.call }
          end
        end
      end

      assert File.exist?(File.join(volume, File.basename(uf2)))
      assert_match(/Found RP2350 at /, out)
      assert_match(/not been verified on real hardware/, err)
    end
  end

  def test_rp2040_install_prints_no_unverified_note
    _, err = capture_io { Prremote::Commands::Install.new(board: 'picow').send(:warn_unverified) }
    assert_empty err
  end

  # Runs call with the UF2 fetch and the post-copy wait stubbed out.
  def run_install(cmd, uf2)
    capture_io do
      Prremote::RuntimeManager.stub(:fetch, uf2) do
        cmd.stub(:wait_for_unmount, nil) { cmd.call }
      end
    end
  end

  def with_uf2
    Dir.mktmpdir do |dir|
      uf2 = File.join(dir, 'prremote-picow-runtime-0.4.2.uf2')
      File.write(uf2, 'uf2')
      yield dir, uf2
    end
  end

  def test_auto_bootsel_touches_pico_port_at_1200_baud
    with_uf2 do |dir, uf2|
      volume  = File.join(dir, 'RPI-RP2')
      cmd     = Prremote::Commands::Install.new(board: 'picow')
      touched = nil
      # The volume shows up only once the board has been touched.
      touch = lambda do |port|
        touched = port
        Dir.mkdir(volume)
        File.write(File.join(volume, Prremote::Commands::Install::BOOTSEL_MARKER), "Board-ID: RPI-RP2\n")
      end

      out, = Prremote::Detector.stub(:find_pico_port, '/dev/cu.usbmodem1') do
        cmd.stub(:volume_paths, [volume]) do
          cmd.stub(:touch_reset_baud, touch) { run_install(cmd, uf2) }
        end
      end

      assert_equal '/dev/cu.usbmodem1', touched
      assert File.exist?(File.join(volume, File.basename(uf2)))
      assert_match(/Rebooting Pico W on \/dev\/cu\.usbmodem1 into BOOTSEL mode/, out)
      refute_match(/Hold the BOOTSEL button/, out)
    end
  end

  def test_auto_bootsel_prefers_explicit_port
    cmd = Prremote::Commands::Install.new(board: 'picow', port: '/dev/cu.usbmodem9')
    touched = nil
    Prremote::Detector.stub(:find_pico_port, -> { flunk 'should not detect' }) do
      cmd.stub(:touch_reset_baud, ->(port) { touched = port }) do
        cmd.stub(:wait_for_volume, '/Volumes/RPI-RP2') do
          capture_io { assert_equal '/Volumes/RPI-RP2', cmd.send(:auto_bootsel) }
        end
      end
    end
    assert_equal '/dev/cu.usbmodem9', touched
  end

  def test_auto_bootsel_skipped_without_pico_port
    cmd = Prremote::Commands::Install.new(board: 'picow')
    Prremote::Detector.stub(:find_pico_port, nil) do
      cmd.stub(:touch_reset_baud, ->(_) { flunk 'should not touch' }) do
        out, = capture_io { assert_nil cmd.send(:auto_bootsel) }
        assert_empty out
      end
    end
  end

  # No runtime on the board (or a wedged one): the drive never appears.
  def test_auto_bootsel_falls_back_to_manual_when_volume_never_appears
    cmd = Prremote::Commands::Install.new(board: 'picow')
    waits = []
    wait = lambda do |timeout: 60|
      waits << timeout
      raise 'Timed out waiting for RPI-RP2 volume' if timeout == Prremote::Commands::Install::AUTO_BOOTSEL_TIMEOUT

      '/Volumes/RPI-RP2'
    end

    out, = capture_io do
      Prremote::Detector.stub(:find_pico_port, '/dev/cu.usbmodem1') do
        cmd.stub(:mounted_volume, nil) do
          cmd.stub(:touch_reset_baud, nil) do
            cmd.stub(:wait_for_volume, wait) do
              volume = cmd.send(:mounted_volume) || cmd.send(:auto_bootsel) || cmd.send(:manual_bootsel)
              assert_equal '/Volumes/RPI-RP2', volume
            end
          end
        end
      end
    end

    assert_equal [Prremote::Commands::Install::AUTO_BOOTSEL_TIMEOUT, 60], waits
    assert_match(/RPI-RP2 did not appear; falling back to manual BOOTSEL/, out)
    assert_match(/Hold the BOOTSEL button/, out)
  end

  def test_touch_reset_baud_opens_port_at_magic_baud
    opened = nil
    fake = Object.new
    def fake.close = nil
    Serial.stub(:new, lambda { |port, baud|
      opened = [port, baud]
      fake
    }) do
      @install.send(:touch_reset_baud, '/dev/cu.usbmodem1')
    end
    assert_equal ['/dev/cu.usbmodem1', 1200], opened
  end

  # The board leaves USB as soon as it sees the baud rate.
  def test_touch_reset_baud_ignores_errors_from_vanishing_port
    Serial.stub(:new, ->(*) { raise RubySerial::Error, 'ENXIO' }) do
      @install.send(:touch_reset_baud, '/dev/cu.usbmodem1')
    end
  end
end
