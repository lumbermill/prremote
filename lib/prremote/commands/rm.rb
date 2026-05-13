module Prremote
  module Commands
    class Rm
      def initialize(connection)
        @conn = connection
      end

      def call(remote_path)
        @conn.run(%(File.delete("#{remote_path}")))
      end
    end
  end
end
