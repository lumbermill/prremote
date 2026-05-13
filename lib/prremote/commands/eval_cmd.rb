module Prremote
  module Commands
    class EvalCmd
      def initialize(connection)
        @conn = connection
      end

      def call(expression)
        @conn.eval_ruby(expression)
      end
    end
  end
end
