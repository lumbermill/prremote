module Prremote
  module Commands
    class Ls
      def initialize(connection)
        @conn = connection
      end

      def call(path = "/")
        @conn.send_line("LS #{path}")
        entries = []
        loop do
          line = @conn.read_line
          raise ProtocolError, line.delete_prefix("ERROR ") if line.start_with?("ERROR")
          break if line == "END"

          entries << line
        end
        entries
      end
    end
  end
end
