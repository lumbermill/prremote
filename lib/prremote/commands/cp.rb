module Prremote
  module Commands
    class Cp
      def initialize(connection)
        @conn = connection
      end

      def call(src_path, dest_path)
        @conn.send_line("CP #{src_path} #{dest_path}")
        response = @conn.read_line
        raise ProtocolError, response.delete_prefix("ERROR ") if response.start_with?("ERROR")
      end
    end
  end
end
