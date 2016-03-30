Gem::Specification.new do |s|
  s.name          = 'secret_fascists'
  s.version       = '1.0.0'
  s.summary       = 'Secret Fascists'
  s.description   = 'Backend for managing a "Secret Fascists" game'
  s.authors       = ['Peter Tseng']
  s.email         = 'pht24@cornell.edu'
  s.homepage      = 'https://github.com/petertseng/secret_fascists'

  s.files         = Dir['LICENSE', 'README.md', 'lib/**/*']
  s.test_files    = Dir['spec/**/*']
  s.require_paths = ['lib']

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
end
