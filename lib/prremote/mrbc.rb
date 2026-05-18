require 'open3'

module Prremote
  # mrbc lookup order:
  #   1. MRBC env var if set (use this to point at a non-PATH binary)
  #   2. PATH entries, excluding rbenv shims — shims delegate to the project's
  #      .ruby-version (typically CRuby) and do not work as a standalone mrbc
  #   3. rbenv direct installs (~/.rbenv/versions/mruby-*/bin/mrbc)
  # The first candidate wins; version compatibility is checked in check_version!.
  module Mrbc
    SHIMS_RE = %r{\.rbenv/shims}
    REQUIRED_MAJOR = 4

    def self.bin
      return ENV['MRBC'] if ENV['MRBC'] && File.executable?(ENV['MRBC'])

      (path_candidates + rbenv_candidates).first ||
        raise('mrbc not found. Install mruby 4.x: brew install mruby')
    end

    def self.version
      out, = Open3.capture2e(bin, '--version')
      out.strip
    rescue RuntimeError
      '(mrbc not found)'
    end

    def self.major_version
      version[/\bmruby (\d+)\./, 1]&.to_i
    end

    def self.check_version!
      return if @version_ok

      major = major_version
      unless major && major >= REQUIRED_MAJOR
        raise "mrbc is mruby #{major || '?'}.x but mruby #{REQUIRED_MAJOR}.x or newer is required.\n" \
              "Installed: #{version}\n" \
              "Install mruby 4.x: brew install mruby\n" \
              "On Linux: build from source (https://github.com/mruby/mruby/releases)"
      end

      @version_ok = true
    end

    private_class_method def self.path_candidates
      ENV['PATH'].split(File::PATH_SEPARATOR)
                 .grep_v(SHIMS_RE)
                 .map { |d| File.join(d, 'mrbc') }
                 .select { |f| File.executable?(f) }
    end

    private_class_method def self.rbenv_candidates
      Dir.glob(File.expand_path('~/.rbenv/versions/mruby-*/bin/mrbc'))
         .select { |f| File.executable?(f) }
    end
  end
end
