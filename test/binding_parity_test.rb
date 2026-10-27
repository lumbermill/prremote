require_relative 'test_helper'

# Every C function a runtime Ruby wrapper calls (`_i2c_probe`, `_lcd_init`, …)
# must be registered with mrbc_define_method in every build that compiles that
# wrapper. A missing one still builds and links — mruby/c only fails at run
# time with NoMethodError — so this is checked here, without hardware.
#
# Boards that lack a feature register an explicit stub that raises (e.g.
# c_ir_unsupported, c_not_on_esp32); a stub counts as registered, an omission
# does not.
class BindingParityTest < Minitest::Test
  RUNTIME = File.expand_path('../runtime', __dir__)

  # What each runtime image compiles: the Ruby wrappers (mrbc -B name) and the
  # C sources that register methods. Keep in sync with the CMake files below;
  # test_builds_match_cmake checks the file names against them.
  # pico2 builds like pico (non-W), and m5stickc_plus runs the esp32 image.
  BUILDS = {
    'pico' => {
      cmake: 'CMakeLists.txt',
      wraps: %w[hw_wrap],
      sources: %w[src/runtime.c src/platform_pico.c src/bindings.c]
    },
    'picow' => {
      cmake: 'CMakeLists.txt',
      wraps: %w[hw_wrap cyw43_wrap time_wrap],
      sources: %w[src/runtime.c src/platform_pico.c src/bindings.c src/bindings_cyw43.c src/ntp.c
                  src/tcp_socket_binding.c src/socket_init.c]
    },
    'esp32' => {
      cmake: 'esp32/main/CMakeLists.txt',
      wraps: %w[hw_wrap lcd_wrap cyw43_wrap time_wrap],
      sources: %w[src/runtime.c src/board_esp_idf.c esp32/main/platform_esp32.c esp32/main/bindings_esp32.c
                  esp32/main/bindings_wifi_esp32.c esp32/main/lcd_ili9342c.c
                  src/tcp_socket_binding.c src/udp_socket_binding.c src/socket_init.c]
    },
    'esp32c6' => {
      cmake: 'esp32c6/main/CMakeLists.txt',
      wraps: %w[hw_wrap lcd_wrap cyw43_wrap time_wrap],
      sources: %w[src/runtime.c src/board_esp_idf.c esp32c6/main/platform_esp32c6.c
                  esp32c6/main/bindings_esp32c6.c esp32/main/bindings_wifi_esp32.c esp32/main/lcd_ili9342c.c
                  src/tcp_socket_binding.c src/udp_socket_binding.c src/socket_init.c]
    }
  }.freeze

  # Comments are dropped so names in prose don't count; "#{" is interpolation.
  COMMENT = /(?:^|\s)#(?!\{).*$/
  BINDING_NAME = /\b_[a-z][a-z0-9_]*[?!]?/
  RUBY_DEF = /\bdef\s+(?:self\.)?(_[a-z][a-z0-9_]*[?!]?)/
  REGISTRATION = /mrbc_define_method\s*\([^,]+,[^,]+,\s*"([^"]+)"/

  def self.wrap_path(name) = File.join(RUNTIME, 'src', "#{name}.rb")

  # Names a wrapper calls that it does not define itself in Ruby.
  def self.called_bindings(wrap)
    code = File.readlines(wrap_path(wrap), encoding: 'UTF-8').map { |line| line.sub(COMMENT, '') }.join
    ruby_defs = code.scan(RUBY_DEF).flatten
    code.scan(BINDING_NAME).uniq - ruby_defs
  end

  def self.registered(sources)
    sources.flat_map { |src| File.read(File.join(RUNTIME, src), encoding: 'UTF-8').scan(REGISTRATION).flatten }.uniq
  end

  def test_builds_match_cmake
    BUILDS.each do |board, build|
      cmake = File.read(File.join(RUNTIME, build[:cmake]), encoding: 'UTF-8')
      build[:wraps].each do |wrap|
        assert_match(/-B #{wrap}\b/, cmake, "#{board}: #{build[:cmake]} does not compile #{wrap}.rb")
      end
      build[:sources].each do |src|
        assert File.file?(File.join(RUNTIME, src)), "#{board}: #{src} does not exist"
        assert_includes cmake, File.basename(src), "#{board}: #{build[:cmake]} does not list #{src}"
      end
    end
  end

  def test_wrappers_call_some_bindings
    BUILDS.values.flat_map { |b| b[:wraps] }.uniq.each do |wrap|
      refute_empty self.class.called_bindings(wrap), "found no _bindings in #{wrap}.rb — is the pattern stale?"
    end
  end

  BUILDS.each do |board, build|
    define_method("test_#{board}_registers_every_binding_its_wrappers_call") do
      registered = self.class.registered(build[:sources])
      missing = build[:wraps].flat_map do |wrap|
        (self.class.called_bindings(wrap) - registered).map { |name| "#{name} (called from #{wrap}.rb)" }
      end

      assert_empty missing, "#{board}: not registered with mrbc_define_method in " \
                            "#{build[:sources].join(', ')}:\n  #{missing.join("\n  ")}"
    end
  end
end
