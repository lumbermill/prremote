require_relative 'test_helper'

class BoardsTest < Minitest::Test
  Boards = Prremote::Boards

  def names(paths) = paths.map { |p| File.basename(p) }

  def test_no_library_when_not_referenced
    assert_empty Boards.library_paths(['puts 6*7'])
  end

  def test_board_library_pulls_in_its_requires_first
    paths = Boards.library_paths(['stick = M5StickCPlus.new'])
    assert_equal %w[bm8563.rb m5stickc_plus.rb], names(paths)
    paths.each { |p| assert File.exist?(p), p }
  end

  def test_chip_driver_alone
    assert_equal %w[bm8563.rb], names(Boards.library_paths(['BM8563.new(i2c)']))
  end

  def test_no_duplicates_when_both_referenced
    paths = Boards.library_paths(%w[BM8563 M5StickCPlus])
    assert_equal %w[bm8563.rb m5stickc_plus.rb], names(paths)
  end

  def test_word_boundary
    assert_empty Boards.library_paths(['MyM5StickCPlusThing = 1'])
  end

  # The plain esp32 image can't tell an M5StickC PLUS from an M5GO, and old
  # runtimes report no board at all — both are allowed.
  def test_allowed_on_shared_image_and_unknown_board
    Boards.check!(['M5StickCPlus'], 'esp32')
    Boards.check!(['M5StickCPlus'], nil)
    Boards.check!(['M5StickCPlus'], 'm5stickc_plus')
    Boards.check!(['BM8563'], 'esp32c6')
  end

  def test_rejects_other_board
    err = assert_raises(RuntimeError) { Boards.check!(['M5StickCPlus'], 'esp32c6') }
    assert_match(/M5StickCPlus is for m5stickc_plus.*board=esp32c6/, err.message)
  end

  def test_firmware_for
    assert_equal 'esp32', Boards.firmware_for('m5stickc_plus')
    assert_equal 'picow', Boards.firmware_for('picow')
  end
end
