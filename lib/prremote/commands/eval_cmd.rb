module Prremote
  module Commands
    class EvalCmd
      def initialize(connection)
        @conn = connection
      end

      def call(expression)
        @conn.send_line("EVAL #{expression}")
        response = @conn.read_line
        raise ProtocolError, response.delete_prefix("ERROR ") if response.start_with?("ERROR")

        response.delete_prefix("OK ")
      end
    end
  end
end
