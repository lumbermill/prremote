require 'open3'

module Prremote
  # esptool lookup order (mirrors Mrbc):
  #   1. ESPTOOL env var if set (use this to point at a non-PATH binary)
  #   2. `esptool` on PATH (pip installs / esptool v5)
  #   3. `esptool.py` on PATH (older pip installs, ESP-IDF environments)
  # esptool v5 renamed subcommands to dashes (write-flash); v4 uses
  # underscores (write_flash) — write_flash_cmd absorbs the difference.
  module Esptool
    def self.bin
      return ENV['ESPTOOL'] if ENV['ESPTOOL'] && File.executable?(ENV['ESPTOOL'])

      found = %w[esptool esptool.py].find { |name| on_path?(name) }
      found || raise('esptool not found. Install it with: pip install esptool ' \
                     '(or brew install esptool), or set $ESPTOOL')
    end

    def self.version
      out, = Open3.capture2e(bin, 'version')
      out[/esptool(?:\.py)? v?(\d+[.\d]*)/, 1]
    rescue RuntimeError
      nil
    end

    def self.write_flash_cmd
      major = version&.split('.')&.first.to_i
      major >= 5 ? 'write-flash' : 'write_flash'
    end

    # Flashes a merged image (bootloader + partition table + app) at 0x0.
    def self.flash(port:, image:, chip: 'esp32', baud: 460_800)
      system(bin, '--chip', chip, '--port', port, '--baud', baud.to_s,
             write_flash_cmd, '0x0', image) ||
        raise('esptool flashing failed')
    end

    private_class_method def self.on_path?(name)
      ENV['PATH'].split(File::PATH_SEPARATOR)
                 .any? { |d| File.executable?(File.join(d, name)) }
    end
  end
end
