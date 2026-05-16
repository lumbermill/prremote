require_relative '../test_helper'

class EvalCmdTest < Minitest::Test
  def test_writes_expression_to_temp_file_and_runs
    received_content = nil

    Prremote::Commands::Run.stub(:new, lambda { |**_|
      obj = Object.new
      obj.define_singleton_method(:call) { |path| received_content = File.read(path) }
      obj
    }) do
      Prremote::Commands::EvalCmd.new(port: '/dev/null', baud: 115_200).call('puts 42')
    end

    assert_equal 'puts 42', received_content
  end

  def test_temp_file_is_cleaned_up
    saved_path = nil

    Prremote::Commands::Run.stub(:new, lambda { |**_|
      obj = Object.new
      obj.define_singleton_method(:call) { |path| saved_path = path }
      obj
    }) do
      Prremote::Commands::EvalCmd.new(port: '/dev/null', baud: 115_200).call('1 + 1')
    end

    refute File.exist?(saved_path), 'Tempfile should be deleted after call'
  end
end
