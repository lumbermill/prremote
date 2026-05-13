module Prremote
  module Commands
    class Mkdir
      def initialize(connection)
        @conn = connection
      end

      def call(remote_path)
        @conn.send_line("MKDIR #{remote_path}")
        response = @conn.read_line
        raise ProtocolError, response.delete_prefix("ERROR ") if response.start_with?("ERROR")
      end
    end
  end
end
