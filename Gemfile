PRIVATE_GEM_SERVER = 'https://gem.fury.io/invoca'

source 'https://rubygems.org'
source PRIVATE_GEM_SERVER

gem 'mysql2', '~> 0.5.2'
gem 'yaml_db'
gem 'rails', '~> 5.2', ">= 5.2.4.4"
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.1'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

gem 'jquery-rails'
gem 'turbolinks'
gem 'jbuilder', '~> 2.0'
gem 'sdoc', '~> 0.4.0', group: :doc

gem 'bootstrap-sass'
gem 'inline_styles_mailer'
gem 'nokogiri', '1.10.8'

group :test do
  gem 'webmock'
  gem 'fakefs', require: 'fakefs/safe'
  gem 'mutant-rspec', require: false
  gem 'timecop'
  gem 'coveralls', '~> 0.8.22', require: false
  gem 'rspec'
  gem 'rspec-its', '~> 1.2'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails'
  gem 'database_cleaner'
  gem 'stub_env'
  gem 'brakeman', require: false
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'bundler-audit', require: false
  gem 'rails-controller-testing'
end

group :development do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'

  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 3.0'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  gem 'foreman'
end

group :production do
  gem 'unicorn'
end

gem 'git_lib', '~> 1.2'
gem 'git_models', '~> 1.2'
gem 'hobo_fields', '~> 3.1', source: PRIVATE_GEM_SERVER
gem 'delayed_job_active_record'
gem 'daemons'
gem 'jira-ruby', '0.1.17', require: 'jira'
gem 'pry'

gem 'invoca_secrets', source: PRIVATE_GEM_SERVER
