# frozen_string_literal: true

$LOAD_PATH.prepend File.expand_path 'lib', __dir__
require 'behold/version'

Gem::Specification.new do |spec|
  spec.name          = 'behold'
  spec.version       = Behold::VERSION
  spec.authors       = ['Shannon Skipper']
  spec.email         = %w[shannonskipper@gmail.com]
  spec.description   = 'Behold!'
  spec.summary       = 'I looked, and there before me was a gem.'
  spec.homepage      = 'https://github.com/havenwood/behold'
  spec.licenses      = %w[MIT]
  spec.files         = %w[Gemfile LICENSE Rakefile README.md] + Dir['{lib,spec}/**/*.rb', 'bin/*']
  spec.require_paths = %w[lib]
  spec.executables   = %w[behold]

  spec.add_dependency 'literal_parser', '~> 1'
  spec.add_development_dependency 'minitest', '~> 5'
  spec.add_development_dependency 'minitest-proveit', '~> 1'
  spec.add_development_dependency 'rake', '~> 13'
end
