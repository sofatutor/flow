Gem::Specification.new do |spec|
  spec.name          = "flow"
  spec.version       = "0.1.0"
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]

  spec.summary       = "A tool to update PR descriptions"
  spec.description   = "A tool to update PR descriptions with links to gem changes"
  spec.homepage      = "https://github.com/yourusername/flow"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.executables   = ["flow"]

  spec.add_dependency "rugged"
  spec.add_dependency "octokit"
  spec.add_dependency "thor"
  spec.add_dependency "tty-prompt"
end
