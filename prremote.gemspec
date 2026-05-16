require_relative 'lib/prremote/version'

Gem::Specification.new do |spec|
  spec.name        = 'prremote'
  spec.version     = Prremote::VERSION
  spec.authors     = ['ITO Yosei']
  spec.email       = ['y-itou@lumber-mill.co.jp']
  spec.summary     = 'CLI tool for deploying and running mruby/c scripts on a Raspberry Pi Pico W over USB serial'
  spec.description = 'Compile and run mruby/c scripts on a Raspberry Pi Pico W over USB serial.'
  spec.homepage    = 'https://github.com/lumbermill/prremote'
  spec.license     = 'MIT'

  spec.required_ruby_version = '>= 3.4'

  spec.files         = Dir['lib/**/*.rb', 'bin/*', 'LICENSE', 'README.md']
  spec.bindir        = 'bin'
  spec.executables   = ['prremote']

  spec.add_dependency 'base64'
  spec.add_dependency 'rubyserial', '~> 0.6'
  spec.add_dependency 'thor', '~> 1.3'

  spec.add_development_dependency 'minitest', '~> 5.25'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rubocop', '~> 1.70'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
