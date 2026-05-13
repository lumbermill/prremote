module Prremote
  module Commands
    class Mkdir
      def initialize(connection)
        @conn = connection
      end

      def call(remote_path)
        @conn.run(%(Dir.mkdir("#{remote_path}")))
      end
    end
  end
end
