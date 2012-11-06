require 'rubygems'
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "norma-ruby"
  gem.homepage = "http://github.com/cjheath/norma-ruby"
  gem.license = "MIT"
  gem.summary = "A loader and API for NORMA fact-based models"
  gem.description = %q{
The Natural Object Role Modeling Architect is a Visual Studio plug-in for
fact-based modeling in ORM2. This gem loads NORMA's .orm files (which are XML)
into a convenient API built using the ActiveFacts API.
}
  gem.email = "clifford.heath@gmail.com"
  gem.authors = ["Clifford Heath"]
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  gem.add_dependency "nokogiri"
  gem.add_dependency "activefacts-api"
  gem.add_development_dependency "rspec", "~> 2.3.0"
  gem.add_development_dependency "bundler", "~> 1.0.0"
  gem.add_development_dependency "jeweler", "~> 1.5.2"
  # gem.add_development_dependency "rcov", ">= 0"
  gem.add_development_dependency "rdoc", ">= 2.4.2"
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
require 'rdoc/task'

gem "rspec", :require => "spec/rake/spectask"

task :default => :spec

desc "Run Rspec tests"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w{-f d}
end

namespace :spec do
  namespace :rubies do
    SUPPORTED_RUBIES = %w{ 1.8.7 1.9.2 1.9.3 jruby-1.7.0 rbx }

    desc "Run Rspec tests on all supported rubies"
    task :all_tasks => [:install_gems, :exec]

    desc "Run `bundle install` on all rubies"
    task :install_gems do
      sh %{ rvm #{SUPPORTED_RUBIES.join(',')} exec bundle install }
    end

    desc "Run `bundle exec rake` on all rubies"
    task :exec do
      sh %{ rvm #{SUPPORTED_RUBIES.join(',')} exec bundle exec rake spec }
    end
  end
end

desc "Run RSpec tests and produce coverage files (results viewable in coverage/index.html)"
RSpec::Core::RakeTask.new(:coverage) do |spec|
  if RUBY_VERSION < '1.9'
    spec.rcov_opts = %{ --exclude spec --exclude gem/* }
    spec.rcov = true
  else
    spec.rspec_opts = %w{ --require simplecov_helper }
  end
end

task :cov => :coverage
task :rcov => :coverage
task :simplecov => :coverage

Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "norma-ruby #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
