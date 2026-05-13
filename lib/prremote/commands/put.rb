module Prremote
  module Commands
    class Put
      CHUNK_SIZE = 256

      def initialize(connection)
        @conn = connection
      end

      def call(local_path, remote_path)
        data = File.binread(local_path)

        # Write in chunks via eval to avoid serial buffer overflow
        @conn.run(%(f = File.open("#{remote_path}", "wb")))

        data.bytes.each_slice(CHUNK_SIZE) do |chunk|
          hex = chunk.map { |b| format("\\x%02x", b) }.join
          @conn.run(%(f.write("#{hex}")))
        end

        @conn.run("f.close")
      end
    end
  end
end
