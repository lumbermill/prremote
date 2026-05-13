require "base64"

module Prremote
  module Commands
    class Get
      def initialize(connection)
        @conn = connection
      end

      def call(remote_path, local_path)
        @conn.run('require "base64"')
        b64 = @conn.run(%(puts Base64.encode64(File.binread("#{remote_path}"))))
        data = Base64.decode64(b64)
        File.binwrite(local_path, data)
      end
    end
  end
end
