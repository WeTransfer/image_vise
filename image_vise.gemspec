# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'image_vise/version'

Gem::Specification.new do |spec|
  spec.name          = "image_vise"
  spec.version       = ImageVise::VERSION
  spec.authors       = ["Julik Tarkhanov"]
  spec.email         = ["me@julik.nl"]

  spec.summary       = "Runtime thumbnailing proxy"
  spec.description   = "Image processing via URLs"
  spec.homepage      = "https://github.com/WeTransfer/image_vise"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end
  
  spec.files         = `git ls-files -z`.split("\x0")
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'patron', '~> 0.9'
  spec.add_dependency 'rmagick', '~> 2.15'
  spec.add_dependency 'ks', '0.0.2'
  spec.add_dependency 'rack', '>= 1', '< 3'
  spec.add_dependency 'format_parser', '>= 0.14.0', '< 1.0'
  spec.add_dependency 'measurometer', '~> 1'

  spec.add_development_dependency 'magic_bytes', '~> 1'
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 12.2"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rspec", "~> 3"
  spec.add_development_dependency "addressable"
  spec.add_development_dependency "strenv"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "pry"
end
