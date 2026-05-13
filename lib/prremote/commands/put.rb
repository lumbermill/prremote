require "base64"

module Prremote
  module Commands
    class Put
      # 36 bytes → 48 base64 chars → 75-char write command (safe for 80-char terminal lines)
      CHUNK_SIZE = 36

      def initialize(connection)
        @conn = connection
      end

      def call(local_path, remote_path)
        data = File.binread(local_path)

        @conn.run(%(require "base64"; f = File.open("#{remote_path}", "wb")))

        data.bytes.each_slice(CHUNK_SIZE) do |chunk|
          b64 = Base64.strict_encode64(chunk.pack("C*"))
          @conn.run(%(f.write(Base64.decode64("#{b64}"))))
        end

        @conn.run("f.close")
      rescue StandardError
        @conn.run("f.close rescue nil")
        raise
      end
    end
  end
end
