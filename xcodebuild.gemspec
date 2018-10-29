lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'xcodebuild/version'

Gem::Specification.new do |spec|
  spec.name          = 'xcodebuild'
  spec.version       = XcodeBuild::VERSION
  spec.authors       = ['Todd Reed']
  spec.email         = ['todd.reed@reactionsoftware.com']

  spec.summary       = %q{A rake task library for building Xcode projects.}
  spec.homepage      = "https://github.com/toddreed/xcodebuild"
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'rake', '~> 12.0'
  spec.add_runtime_dependency 'xcpretty', '~> 0.3'
  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
end
