require 'tempfile'
require_relative 'run'

module Prremote
  module Commands
    class EvalCmd
      def initialize(port:, baud:)
        @port = port
        @baud = baud
      end

      def call(expr)
        tmp = Tempfile.new(['prremote_eval', '.rb'])
        tmp.write(expr)
        tmp.flush
        Run.new(port: @port, baud: @baud).call(tmp.path)
      ensure
        tmp&.close!
      end
    end
  end
end
