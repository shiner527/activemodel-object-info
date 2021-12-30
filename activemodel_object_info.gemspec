# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activemodel_object_info/version'

Gem::Specification.new do |spec|
  spec.name          = 'activemodel_object_info'
  spec.version       = ActivemodelObjectInfo::Version::VERSION
  spec.authors       = ['shiner']
  spec.email         = ['shiner527@hotmail.com']

  spec.summary       = 'Build a hash based on active record attributes.'
  spec.description   = 'Build a hash based on active record attributes.'
  spec.homepage      = 'https://github.com/shiner527/activemodel-object-info'
  spec.license       = 'MIT'

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/shiner527/activemodel-object-info.git'
  spec.metadata['changelog_uri'] = 'https://github.com/shiner527/activemodel-object-info/CHANGELOG'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'

  spec.add_development_dependency 'activerecord'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'yard'
  spec.metadata = {
    'rubygems_mfa_required' => 'false',
  }
end
