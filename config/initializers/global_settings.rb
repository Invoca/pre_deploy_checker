# Load application configuration
require 'ostruct'
require 'yaml'

DEFAULT_SETTINGS = {
  cache_directory: './tmp/cache/git',
  web_server_url: '',
  jira: {}
}.freeze

DEFAULT_JIRA_SETTINGS = {
  private_key_file: './rsakey.pem',
  project_keys: [],
  valid_statuses: [],
  valid_sub_task_statuses: [],
  valid_post_deploy_check_statuses: [],
  ignore_commits_with_messages: [],
  ignore_branches: [],
  only_branches: [],
  ancestor_branches: {}
}.freeze

class InvalidSettings < StandardError; end

def skip_validations
  ENV['VALIDATE_SETTINGS']&.casecmp('false')
end

def validate_common_settings(settings)
  return if skip_validations

  settings or raise ArgumentError, "settings must not be falsey"

  settings.empty? and raise InvalidSettings, 'jira settings must not be empty'

  if settings.web_server_url.blank?
    raise InvalidSettings, 'Must specify the web server URL'
  end
end

def validate_jira_settings(jira_settings)
  return if skip_validations

  Rails.application.secrets.jira[:'site'].blank? and raise InvalidSettings, 'Must specify JIRA site URL'
  Rails.application.secrets.jira[:'consumer_key'].blank? and raise InvalidSettings, 'Must specify JIRA consumer key'
  Rails.application.secrets.jira[:'access_token'].blank? and raise InvalidSettings, 'Must specify JIRA access token'
  Rails.application.secrets.jira[:'access_key'].blank? and raise InvalidSettings, 'Must specify JIRA access key'
  Rails.application.secrets.jira[:'private_key_file'].blank? and raise InvalidSettings, 'Must specify JIRA private key file name'
  jira_settings.project_keys.empty? and raise InvalidSettings, 'Must specify at least one JIRA project key'
  jira_settings.ancestor_branches.empty? and raise InvalidSettings, 'Must specify at least one JIRA ancestor branch mapping'
  jira_settings.valid_statuses.empty? and raise InvalidSettings, 'Must specify at least one valid JIRA status'
  jira_settings.valid_sub_task_statuses.empty? and raise InvalidSettings, 'Must specify at least one valid JIRA sub-task status'

  jira_settings.ancestor_branches.each do |branch, ancestor_branch|
    ancestor_branch.blank? and raise InvalidSettings, "Must specify an ancestor branch for #{branch}"
  end
end

def load_global_settings
  settings_path = Rails.root.join('data', 'config', "settings.#{Rails.env}.yml")
  settings_hash = if File.exist?(settings_path)
                    YAML.load_file(settings_path) || {}
                  else
                    {}
                  end

  unless settings_hash.is_a?(Hash)
    raise InvalidSettings, 'Settings file is not a hash'
  end

  # convert to open struct
  settings_object = OpenStruct.new(DEFAULT_SETTINGS.merge(settings_hash))
  settings_object.empty? and raise 'Settings are empty!'

  validate_common_settings(settings_object)

  if settings_hash['jira']
    settings_object.jira = OpenStruct.new(DEFAULT_JIRA_SETTINGS.merge(settings_object.jira))
    validate_jira_settings(settings_object.jira)
  end

  settings_object
end

GlobalSettings = load_global_settings
