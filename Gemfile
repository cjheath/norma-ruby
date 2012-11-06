source 'https://rubygems.org'

gem 'nokogiri'
gem 'activefacts-api'

group :development do
  gem 'rake'
  gem 'jeweler'
  gem 'rspec', '~>2.6.0'
  gem 'ruby-debug', :platforms => [:mri_18]
  gem 'debugger', :platforms => [:mri_19]
  gem 'pry', :platforms => [:jruby, :rbx]
end

group :test do
  gem 'rake'
  # rcov 1.0.0 is broken for jruby, so 0.9.11 is the only one available.
  gem 'rcov', '~>0.9.11', :platforms => [:jruby, :mri_18], :require => false
  gem 'simplecov', '~>0.6.4', :platforms => :mri_19, :require => false
end
