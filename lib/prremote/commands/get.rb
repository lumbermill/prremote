require "base64"

module Prremote
  module Commands
    class Get
      def initialize(connection)
        @conn = connection
      end

      def call(remote_path, local_path)
        # Read file as base64 to safely transfer binary data
        b64 = @conn.run(
          %(require "base64"; puts Base64.encode64(File.binread("#{remote_path}")))
        )
        data = Base64.decode64(b64)
        File.binwrite(local_path, data)
      end
    end
  end
end
