require 'rake/testtask'
require 'rubygems/package_task'

spec = Gem::Specification.load('prremote.gemspec')
Gem::PackageTask.new(spec) { |_pkg| }


Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/**/*_test.rb'].exclude('test/integration_test.rb')
  t.verbose = false
end

Rake::TestTask.new(:integration) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/integration_test.rb']
  t.verbose = false
end

task default: :test
