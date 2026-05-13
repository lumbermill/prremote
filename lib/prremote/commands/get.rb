module Prremote
  module Commands
    class Get
      def initialize(connection)
        @conn = connection
      end

      def call(remote_path, local_path)
        @conn.send_line("GET #{remote_path}")
        response = @conn.read_line
        raise ProtocolError, response.delete_prefix("ERROR ") if response.start_with?("ERROR")
        raise ProtocolError, "Expected SIZE, got: #{response}" unless response.start_with?("SIZE ")

        size = response.delete_prefix("SIZE ").to_i
        data = @conn.read_bytes(size)
        File.binwrite(local_path, data)
      end
    end
  end
end
