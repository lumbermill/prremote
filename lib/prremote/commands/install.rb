require "net/http"
require "json"
require "rbconfig"

module Prremote
  module Commands
    class Install
      FIRMWARE_REPO = "prremote/firmware"

      BOARD_FILES = {
        "pico"   => "prremote-agent-pico.uf2",
        "pico_w" => "prremote-agent-pico_w.uf2"
      }.freeze

      MOUNT_PATHS = {
        "darwin" => "/Volumes/RPI-RP2",
        "linux"  => "/media/#{ENV.fetch('USER', 'user')}/RPI-RP2"
      }.freeze

      def call(board: "pico", list_versions: false)
        if list_versions
          versions.each { |v| puts v }
          return
        end

        uf2_file = BOARD_FILES[board]
        raise "Unknown board: #{board}. Available: #{BOARD_FILES.keys.join(', ')}" unless uf2_file

        puts "Downloading firmware for #{board}…"
        data = download_latest(uf2_file)

        mount = detect_mount
        unless mount
          puts ""
          puts "Please put your Pico into BOOTSEL mode:"
          puts "  Hold the BOOTSEL button, then connect USB (or press reset while holding BOOTSEL)."
          puts ""
          print "Press Enter when the RPI-RP2 drive appears… "
          $stdin.gets
          mount = wait_for_mount
        end

        raise "RPI-RP2 drive not found. Is the Pico in BOOTSEL mode?" unless mount

        dest = File.join(mount, uf2_file)
        puts "Writing #{uf2_file} to #{mount}…"
        File.binwrite(dest, data)
        puts "Done! The Pico will reboot automatically."
      end

      private

      def versions
        uri = URI("https://api.github.com/repos/#{FIRMWARE_REPO}/releases")
        res = Net::HTTP.get_response(uri)
        raise "Failed to fetch releases: #{res.code}" unless res.is_a?(Net::HTTPSuccess)

        JSON.parse(res.body).map { |r| r["tag_name"] }
      end

      def download_latest(filename)
        uri = URI("https://api.github.com/repos/#{FIRMWARE_REPO}/releases/latest")
        res = Net::HTTP.get_response(uri)
        raise "Failed to fetch latest release: #{res.code}" unless res.is_a?(Net::HTTPSuccess)

        release = JSON.parse(res.body)
        asset = release["assets"].find { |a| a["name"] == filename }
        raise "Firmware file #{filename} not found in latest release." unless asset

        download_url(asset["browser_download_url"])
      end

      def download_url(url)
        uri = URI(url)
        res = Net::HTTP.get_response(uri)
        # Follow one redirect (GitHub releases use a CDN redirect)
        if res.is_a?(Net::HTTPRedirection)
          res = Net::HTTP.get_response(URI(res["location"]))
        end
        raise "Download failed: #{res.code}" unless res.is_a?(Net::HTTPSuccess)

        res.body
      end

      def detect_mount
        os_key = RbConfig::CONFIG["host_os"].match?(/darwin/) ? "darwin" : "linux"
        path = MOUNT_PATHS[os_key]
        File.directory?(path) ? path : nil
      end

      def wait_for_mount(timeout: 30)
        deadline = Time.now + timeout
        loop do
          mount = detect_mount
          return mount if mount
          break if Time.now > deadline

          sleep 0.5
        end
        nil
      end
    end
  end
end
