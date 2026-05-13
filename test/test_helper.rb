require "minitest/autorun"
require "prremote"

class FakeConnection
  attr_reader :sent_lines, :sent_bytes

  def initialize
    @sent_lines = []
    @sent_bytes = []
    @line_queue = []
    @byte_queue = []
  end

  def queue_line(line)
    @line_queue << line
  end

  def queue_bytes(data)
    @byte_queue << data
  end

  def send_line(text)
    @sent_lines << text
  end

  def write_bytes(data)
    @sent_bytes << data
  end

  def read_line(timeout: nil)
    raise Prremote::TimeoutError, "no queued response" if @line_queue.empty?

    @line_queue.shift
  end

  def read_bytes(n, timeout: nil)
    data = @byte_queue.shift || "".b
    data.byteslice(0, n) || "".b
  end

  def open?
    true
  end
end
