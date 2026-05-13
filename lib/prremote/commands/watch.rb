module Prremote
  module Commands
    class Watch
      POLL_INTERVAL = 0.5

      def initialize(connection)
        @conn = connection
      end

      def call(local_path, remote_path)
        raise ArgumentError, "File not found: #{local_path}" unless File.exist?(local_path)

        last_mtime = File.mtime(local_path)
        puts "Watching #{local_path} → #{remote_path} (Ctrl-C to stop)…"
        loop do
          sleep POLL_INTERVAL
          mtime = File.mtime(local_path)
          next if mtime == last_mtime

          last_mtime = mtime
          Put.new(@conn).call(local_path, remote_path)
          @conn.send_line("RESET")
          puts "[#{Time.now.strftime('%H:%M:%S')}] Uploaded → reset."
        end
      rescue Interrupt
        puts "\nStopped."
      end
    end
  end
end
