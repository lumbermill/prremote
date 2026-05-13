require_relative "lib/prremote/version"

Gem::Specification.new do |spec|
  spec.name        = "prremote"
  spec.version     = Prremote::VERSION
  spec.authors     = ["ITO Yosei"]
  spec.email       = ["y-itou@lumber-mill.co.jp"]
  spec.summary     = "CLI tool for remotely interacting with PicoRuby/R2P2 devices over serial"
  spec.description = "prremote lets you access a PicoRuby/R2P2 shell, transfer files, and run scripts on a Raspberry Pi Pico over USB serial — inspired by mpremote for MicroPython."
  spec.homepage    = "https://github.com/picoruby/prremote"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*.rb", "bin/*", "LICENSE", "README.md"]
  spec.bindir        = "bin"
  spec.executables   = ["prremote"]

  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "rubyserial", "~> 0.6"
  spec.add_dependency "base64"

  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "rubocop", "~> 1.70"
end
