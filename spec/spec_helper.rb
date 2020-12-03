# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require 'coveralls'
require 'rspec_junit_formatter'
Coveralls.wear!('rails') if ENV['CI'] == 'true'
require_relative '../config/environment'
require 'rails/test_help'
require 'git/git_test_helpers'
require 'database_cleaner'
require 'rake'
require 'rspec/rails'
require 'fakefs/spec_helpers'
require 'webmock/rspec'
require 'digest/sha1'
require 'securerandom'
require 'helpers/deploy_email_interceptor'
require 'helpers/git_helpers'

GitConflictDetector::Application.load_tasks

RSpec.configure do |config|
  config.add_formatter(RspecJunitFormatter, 'spec/reports/rspec.xml')

  config.include StubEnv::Helpers
  config.include GitHelpers

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    Rake::Task['db:test:prepare'].invoke
  end

  config.around(:each) do |example|
    # reload settings each time in case the tests are mutating them
    Object.send(:remove_const, :GlobalSettings)
    GlobalSettings = load_global_settings
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.around(:each, :disable_delayed_job) do |example|
    old_value = Delayed::Worker.delay_jobs
    Delayed::Worker.delay_jobs = false
    example.run
    Delayed::Worker.delay_jobs = old_value
  end

  config.filter_run_when_matching :focus
  ActionMailer::Base.register_interceptor(DeployEmailInterceptor)
end

def load_json_fixture(fixture_name)
  JSON.parse(load_fixture_file("#{fixture_name}.json"))
end

def load_fixture_file(fixture_file_name)
  File.read(Rails.root.join("spec/fixtures/#{fixture_file_name}"))
end

def create_test_push(sha: nil)
  Service.find_or_create_by!(name: "web")
  json = load_json_fixture('github_push_payload')
  if sha
    json['after'] = sha
    json['head_commit']['id'] = sha
  end
  Push.create_from_github_data!(Github::Api::PushHookPayload.new(json)).first
end

def create_test_jira_issue_json(key: nil,
                                status: nil,
                                post_deploy_check_status: 'Ready to Run',
                                deploy_type: nil,
                                parent_key: nil,
                                long_running_migration: 'No')
  json = if parent_key
           load_json_fixture('jira_sub_task_response')
         else
           load_json_fixture('jira_issue_response')
         end
  json['id'] = SecureRandom.random_number(100000).to_s
  if key
    json['key'] = key
  end

  if status
    json['fields']['status']['name'] = status
  end

  if parent_key
    json['fields']['parent']['key'] = parent_key
  else
    # these fields are only valid for non-sub-tasks
    if post_deploy_check_status
      json['fields']['customfield_12202']['value'] = post_deploy_check_status
    else
      json['fields'].except!('customfield_12202')
    end

    if deploy_type
      json['fields']['customfield_12501'][0]['value'] = deploy_type
    end

    if long_running_migration
      json['fields']['customfield_10601'][0]['value'] = long_running_migration
    else
      json['fields'].except!('customfield_10601')
    end
  end

  json
end

def create_test_jira_issue(key: nil,
                           status: nil,
                           post_deploy_check_status: nil,
                           deploy_type: nil,
                           parent_key: nil)
  JiraIssue.create_from_jira_data!(
    JIRA::Resource::IssueFactory.new(nil).build(
      create_test_jira_issue_json(
        key: key,
        status: status,
        post_deploy_check_status: post_deploy_check_status,
        deploy_type: deploy_type,
        parent_key: parent_key
      )
    )
  )
end
