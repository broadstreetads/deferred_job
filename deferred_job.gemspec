spec = Gem::Specification.new do |s|
  s.name = 'deferred_job'
  s.authors = ['John Crepezzi', 'Aubrey Holland']
  s.description = 'Deferred Jobs'
  s.email = 'aubrey@brewster.com'
  s.add_development_dependency 'resque'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'activesupport'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sidekiq'
  s.add_dependency 'multi_json'
  s.files = Dir['lib/**/*.rb'] + ['README.md']
  s.homepage = 'http://github.com/brewster/deferred_job'
  s.platform = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.summary = 'Deferred job library for Resque or Sidekiq'
  s.test_files = Dir.glob('spec/*.rb')
  s.version = '0.1.1' # TODO
end
