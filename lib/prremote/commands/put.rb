module Prremote
  module Commands
    class Put
      def initialize(connection)
        @conn = connection
      end

      def call(local_path, remote_path)
        data = File.binread(local_path)
        @conn.send_line("PUT #{remote_path} #{data.bytesize}")
        response = @conn.read_line
        raise ProtocolError, "Expected READY, got: #{response}" unless response == "READY"

        @conn.write_bytes(data)
        response = @conn.read_line
        raise ProtocolError, response.delete_prefix("ERROR ") if response.start_with?("ERROR")
      end
    end
  end
end
