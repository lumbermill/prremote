require_relative "lib/prremote/version"

Gem::Specification.new do |spec|
  spec.name        = "prremote"
  spec.version     = Prremote::VERSION
  spec.authors     = ["ITO Yosei"]
  spec.email       = ["y-itou@lumber-mill.co.jp"]
  spec.summary     = "CLI tool for remotely interacting with PicoRuby devices over a custom serial protocol"
  spec.description = "prremote transfers files and evaluates Ruby expressions on a Raspberry Pi Pico running the prremote-agent firmware, using a lightweight custom serial protocol — inspired by mpremote for MicroPython."
  spec.homepage    = "https://github.com/picoruby/prremote"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*.rb", "bin/*", "LICENSE", "README.md"]
  spec.bindir        = "bin"
  spec.executables   = ["prremote"]

  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "rubyserial", "~> 0.6"

  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.70"
end
