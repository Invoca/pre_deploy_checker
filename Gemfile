# frozen_string_literal: true

PRIVATE_GEM_SERVER = 'https://gem.fury.io/invoca'

source 'https://rubygems.org'
source PRIVATE_GEM_SERVER

gem 'bootstrap-sass'
gem 'coffee-rails',   '~> 4.1'
gem 'daemons'
gem 'declare_schema', '~> 0.7' #, '>= 0.7.1'
gem 'delayed_job_active_record'
gem 'git_lib',        '~> 1.2'
gem 'inline_styles_mailer'
gem 'invoca_secrets', source: PRIVATE_GEM_SERVER
gem 'jbuilder',       '~> 2.0'
gem 'jira-ruby',      '0.1.17', require: 'jira'
gem 'jquery-rails'
gem 'mysql2',         '~> 0.5.2'
gem 'nokogiri',       '~> 1.11'
gem 'pry'
gem 'pry-byebug'
gem 'rails',          '~> 5.2', ">= 5.2.4.4"
gem 'sass-rails',     '~> 5.0'
gem 'sdoc',           '~> 0.4', group: :doc
gem 'turbolinks'
gem 'uglifier',       '>= 1.3.0'
gem 'yaml_db'

group :test do
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'coveralls',    '~> 0.8', require: false
  gem 'database_cleaner'
  gem 'fakefs', require: 'fakefs/safe'
  gem 'mutant-rspec', require: false
  gem 'rails-controller-testing'
  gem 'rspec'
  gem 'rspec-its',    '~> 1.2'
  gem 'rspec-rails'
  gem 'rspec_junit_formatter'
  gem 'rubocop', require: false
  gem 'rubocop-rspec', require: false
  gem 'stub_env'
  gem 'timecop'
  gem 'webmock'
end

group :development do
  gem 'byebug'
  gem 'foreman'
  gem 'spring'
  gem 'web-console',  '~> 3.0'
end

group :production do
  gem 'unicorn'
end
