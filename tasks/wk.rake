# rake wk:sync[dir] — copy example scripts into wk/ (gitignored) and fill in
# real Wi-Fi credentials, so on-device testing never edits the tracked samples.
# The samples must keep placeholder creds (enforced by the pre-push hook in the
# root Rakefile); this task is how you get runnable, credentialed copies.
#
#   rake wk:sync            # all of examples/ -> wk/examples/
#   rake wk:sync[xiao_c6]   # just examples/xiao_c6 -> wk/examples/xiao_c6
#
# Credentials come from wk/wifi.env (gitignored) or the WIFI_SSID / WIFI_PASS
# environment variables — never from a tracked file. The first run writes a
# wk/wifi.env template and stops so you can fill it in once.
#
# wk/examples/ is a generated mirror: re-running overwrites it. Don't hand-edit
# it — edit the source under examples/ (placeholders) or your own wk/ script.

require 'fileutils'

module Wk
  SRC_ROOT  = 'examples'.freeze
  DEST_ROOT = 'wk/examples'.freeze
  CRED_FILE = 'wk/wifi.env'.freeze

  # The placeholder string literals the tracked samples ship with. Only these
  # exact quoted values are swapped, so any variable name (SSID, WIFI_SSID, …)
  # is covered without touching unrelated strings.
  PLACEHOLDER_SSID = 'MySSID'.freeze
  PLACEHOLDER_PASS = 'MyPassword'.freeze

  module_function

  # [ssid, pass] from the environment, else wk/wifi.env. Aborts (with a helpful
  # message) rather than inventing credentials, so none are ever hardcoded here.
  def credentials
    ssid = ENV['WIFI_SSID'].to_s
    pass = ENV['WIFI_PASS'].to_s
    return [ssid, pass] unless ssid.empty? || pass.empty?

    credentials_from_file
  end

  def credentials_from_file
    unless File.exist?(CRED_FILE)
      write_template
      abort "Wrote #{CRED_FILE} — fill in WIFI_SSID / WIFI_PASS, then re-run.\n" \
            "(wk/ is gitignored, so #{CRED_FILE} is never committed.)"
    end

    env = parse_env(CRED_FILE)
    ssid = env['WIFI_SSID'].to_s
    pass = env['WIFI_PASS'].to_s
    abort "#{CRED_FILE} is missing WIFI_SSID / WIFI_PASS — fill it in and re-run." if ssid.empty? || pass.empty?

    [ssid, pass]
  end

  def parse_env(path)
    File.readlines(path, chomp: true).each_with_object({}) do |line, env|
      next if line.strip.empty? || line.strip.start_with?('#')

      key, value = line.split('=', 2)
      env[key.strip] = value.to_s.strip if key
    end
  end

  def write_template
    FileUtils.mkdir_p(File.dirname(CRED_FILE))
    File.write(CRED_FILE, <<~ENV)
      # Real Wi-Fi credentials for on-device testing. This file lives under wk/,
      # which is gitignored, so it is never committed. `rake wk:sync` reads it to
      # fill the placeholder SSID/PASSWORD in the copied example scripts.
      WIFI_SSID=
      WIFI_PASS=
    ENV
  end

  def sync(subdir)
    src = subdir.empty? ? SRC_ROOT : File.join(SRC_ROOT, subdir)
    abort "No such example dir: #{src}" unless File.directory?(src)

    ssid, pass = credentials
    dest = subdir.empty? ? DEST_ROOT : File.join(DEST_ROOT, subdir)
    FileUtils.mkdir_p(dest)

    # Trailing slashes so rsync mirrors the contents of src into dest.
    # (`sh` isn't in scope inside a module method, so shell out directly.)
    abort 'rsync failed' unless system('rsync', '-a', '--delete', "#{src}/", "#{dest}/")

    filled = fill_credentials(dest, ssid, pass)
    puts "Synced #{src}/ -> #{dest}/ (filled Wi-Fi creds in #{filled} file(s))."
    puts "Run e.g.: SMOKE_WIFI=#{dest}/xiao_c6/wifi.rb rake smoke[esp32c6]" if subdir.empty?
  end

  # Swap the quoted placeholders in the copied .rb files only. Block-form gsub
  # keeps the credential literal (backslashes, digits) from being reinterpreted
  # as a regexp replacement.
  def fill_credentials(dir, ssid, pass)
    count = 0
    Dir.glob(File.join(dir, '**', '*.rb')).each do |path|
      # Force UTF-8: some samples have non-ASCII comments (e.g. "→"), which
      # blow up gsub if the process default encoding is US-ASCII.
      original = File.read(path, encoding: 'UTF-8')
      swapped = original
                .gsub(/(["'])#{Regexp.escape(PLACEHOLDER_SSID)}\1/) { "#{Regexp.last_match(1)}#{ssid}#{Regexp.last_match(1)}" }
                .gsub(/(["'])#{Regexp.escape(PLACEHOLDER_PASS)}\1/) { "#{Regexp.last_match(1)}#{pass}#{Regexp.last_match(1)}" }
      next if swapped == original

      File.write(path, swapped)
      count += 1
    end
    count
  end
end

namespace :wk do
  desc 'Copy examples/ into wk/examples/ (gitignored) with real Wi-Fi creds filled in'
  task :sync, [:dir] do |_t, args|
    Wk.sync(args[:dir].to_s)
  end
end
