module Prremote
  module Commands
    class Run
      def initialize(connection)
        @conn = connection
      end

      # Upload the script to a temp path, load it, then delete it.
      def call(local_path, remote_tmp: "/tmp/_prremote_run.rb")
        Put.new(@conn).call(local_path, remote_tmp)
        output = @conn.run(%(load "#{remote_tmp}"), timeout: 30)
        @conn.run(%(File.delete("#{remote_tmp}")))
        output
      end
    end
  end
end
