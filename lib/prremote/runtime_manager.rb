require 'net/http'
require 'uri'
require 'fileutils'

module Prremote
  module RuntimeManager
    BOARDS = %w[pico picow esp32].freeze

    # Pico boards ship as UF2 (copied to the BOOTSEL drive); ESP32 ships as a
    # single merged .bin (bootloader + partition table + app) flashed at 0x0
    # with esptool.
    def self.artifact_filename(version, board)
      ext = board == 'esp32' ? 'bin' : 'uf2'
      "prremote-#{board}-runtime-#{version}.#{ext}"
    end

    def self.release_url(version, board)
      "https://github.com/lumbermill/prremote/releases/download/runtime-#{version}/#{artifact_filename(version, board)}"
    end

    def self.cache_dir
      File.join(Dir.home, '.prremote', 'runtime')
    end

    def self.cached_path(version, board)
      File.join(cache_dir, artifact_filename(version, board))
    end

    def self.fetch(version, board)
      path = cached_path(version, board)
      return path if File.exist?(path)

      FileUtils.mkdir_p(cache_dir)
      $stderr.print "Downloading #{artifact_filename(version, board)}..."
      $stderr.flush
      download(release_url(version, board), path)
      warn ' done.'
      path
    end

    def self.download(url, dest, redirects = 5)
      raise 'Too many redirects' if redirects.zero?

      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(Net::HTTP::Get.new(uri))
      end

      case response
      when Net::HTTPRedirection
        download(response['Location'], dest, redirects - 1)
      when Net::HTTPSuccess
        File.binwrite(dest, response.body)
      else
        FileUtils.rm_f(dest)
        raise "Download failed: #{response.code} #{response.message}"
      end
    end
  end
end
