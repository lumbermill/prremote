module Prremote
  # Board support libraries: Ruby files under lib/prremote/boards/ that run on
  # the device (not on the host). They are compiled into the user's script
  # only when the script references one of their constants, so scripts that
  # don't use them pay nothing in device heap / symbol table.
  #
  # A board name is what `install -b NAME` records on the device and what the
  # runtime reports in its READY banner (`READY prremote-runtime/X board=NAME`).
  # Several board names can share one runtime image (FIRMWARE).
  module Boards
    LIB_DIR = File.expand_path('boards', __dir__)

    # Board name => runtime image it runs. Boards not listed here are their
    # own image (pico, picow, esp32, esp32c6, ...).
    FIRMWARE = {
      'm5stickc_plus' => 'esp32'
    }.freeze

    # file:      path under LIB_DIR
    # constants: referencing any of these pulls the library in
    # boards:    board names it is written for (nil = any board)
    # requires:  other library files it needs, compiled before it
    Library = Struct.new(:file, :constants, :boards, :requires, keyword_init: true)

    LIBRARIES = [
      Library.new(file: 'bm8563.rb', constants: %w[BM8563], boards: nil, requires: []),
      Library.new(file: 'm5stickc_plus.rb', constants: %w[M5StickCPlus],
                  boards: %w[m5stickc_plus], requires: %w[bm8563.rb])
    ].freeze

    module_function

    def firmware_for(board)
      FIRMWARE.fetch(board, board)
    end

    # Board names `install` accepts on top of the plain runtime images.
    def names
      FIRMWARE.keys
    end

    # Library file paths to compile ahead of the user's sources, in dependency
    # order. `board` is the device's reported board (nil if the runtime is too
    # old to report one). Raises if a referenced library is for another board.
    def library_paths(sources, board)
      wanted = LIBRARIES.select { |lib| referenced?(lib, sources) }
      wanted.each { |lib| check_board!(lib, board) }

      files = []
      wanted.each { |lib| add_with_requires(lib.file, files) }
      files.map { |f| File.join(LIB_DIR, f) }
    end

    def referenced?(lib, sources)
      lib.constants.any? { |c| sources.any? { |src| src.match?(/\b#{c}\b/) } }
    end

    # A board library also runs on a device that only reports its runtime
    # image name (installed with the plain `-b esp32`, or a runtime older than
    # board names), since the host cannot tell those boards apart.
    def check_board!(lib, board)
      return if lib.boards.nil? || board.nil?
      return if lib.boards.include?(board)
      return if lib.boards.any? { |b| firmware_for(b) == board }

      raise "#{lib.constants.join('/')} is for #{lib.boards.join('/')}, " \
            "but the device reports board=#{board}"
    end

    def add_with_requires(file, files)
      return if files.include?(file)

      lib = LIBRARIES.find { |l| l.file == file }
      lib&.requires&.each { |dep| add_with_requires(dep, files) }
      files << file
    end
  end
end
