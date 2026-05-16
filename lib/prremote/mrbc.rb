require 'open3'

module Prremote
  module Mrbc
    SHIMS_RE = %r{\.rbenv/shims}

    def self.bin
      return ENV['MRBC'] if ENV['MRBC'] && File.executable?(ENV['MRBC'])

      found = ENV['PATH'].split(File::PATH_SEPARATOR)
                         .grep_v(SHIMS_RE)
                         .map    { |d| File.join(d, 'mrbc') }
                         .find   { |f| File.executable?(f) }

      found || raise('mrbc not found. Install mruby: brew install mruby')
    end

    def self.version
      out, = Open3.capture2e(bin, '--version')
      out.strip
    rescue RuntimeError
      '(mrbc not found)'
    end
  end
end
