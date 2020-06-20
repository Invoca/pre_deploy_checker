source 'https://rubygems.org'

gem 'rails', '~> 5.2', '5.2.4.3'
gem 'sqlite3'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.1'

gem 'jquery-rails'
gem 'turbolinks'
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

gem 'bootstrap-sass'
gem 'inline_styles_mailer'
gem 'nokogiri', '~> 1.10'

group :test do
  gem 'webmock'
  gem 'fakefs', require: 'fakefs/safe'
  gem 'mutant-rspec', require: false
  gem 'timecop'
  gem 'coveralls', '~> 0.8'
  gem 'rspec'
  gem 'rspec-rails'
  gem 'database_cleaner'
  gem 'stub_env'
  gem 'brakeman', require: false
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'bundler-audit', require: false
end

group :development do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'

  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  gem 'foreman'
end

group :production do
  gem 'unicorn'
end

gem 'git_lib', '~> 2.0', path: '../git_lib'
gem 'git_models', '~> 2.0', path: '../git_models'
gem 'hobo_fields', '~> 3.0', path: '../hobo_fields'
gem 'delayed_job_active_record'
gem 'daemons'
gem 'jira-ruby', require: 'jira'
gem 'pry'

gem 'invoca_secrets', source: 'https://gem.fury.io/invoca'
