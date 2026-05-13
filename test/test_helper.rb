require "minitest/autorun"
require "prremote"

class FakeConnection
  attr_reader :run_calls, :eval_calls

  def initialize(*responses)
    @queue      = responses.flatten
    @run_calls  = []
    @eval_calls = []
  end

  def run(cmd, **)
    @run_calls << cmd
    @queue.shift || ""
  end

  def eval_ruby(expr, **)
    @eval_calls << expr
    @queue.shift || ""
  end

  def open?
    true
  end
end
