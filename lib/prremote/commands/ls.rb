module Prremote
  module Commands
    class Ls
      def initialize(connection)
        @conn = connection
      end

      def call(path = "/")
        output = @conn.run("ls #{path}")
        output.lines.map(&:chomp).reject(&:empty?)
      end
    end
  end
end
