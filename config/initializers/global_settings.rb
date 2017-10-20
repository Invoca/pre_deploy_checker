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
  valid_post_deploy_check_statuses: [],
  ignore_commits_with_messages: [],
  ignore_branches: [],
  only_branches: [],
  ancestor_branches: {},
  deploy_types_for_repos: {}
}.freeze

class InvalidSettings < StandardError; end

def skip_validations
  ENV['VALIDATE_SETTINGS'] && ENV['VALIDATE_SETTINGS'].casecmp('false')
end

def validate_common_settings(settings)
  return if skip_validations

  unless settings.jira._?.any?
    raise InvalidSettings,
          'Must specify jira settings'
  end

  if settings.web_server_url.blank?
    raise InvalidSettings, 'Must specify the web server URL'
  end
end

def validate_jira_settings(settings)
  return if skip_validations

  if Rails.application.secrets.jira['site'].blank?
    raise InvalidSettings, 'Must specify JIRA site URL'
  end
  if Rails.application.secrets.jira['consumer_key'].blank?
    raise InvalidSettings, 'Must specify JIRA consumer key'
  end
  if Rails.application.secrets.jira['access_token'].blank?
    raise InvalidSettings, 'Must specify JIRA access token'
  end
  if Rails.application.secrets.jira['access_key'].blank?
    raise InvalidSettings, 'Must specify JIRA access key'
  end
  if Rails.application.secrets.jira['private_key_file'].blank?
    raise InvalidSettings, 'Must specify JIRA private key file name'
  end
  if settings.project_keys.empty?
    raise InvalidSettings, 'Must specify at least one JIRA project key'
  end
  if settings.ancestor_branches.empty?
    raise InvalidSettings, 'Must specify at least one JIRA ancestor branch mapping'
  end
  if settings.valid_statuses.empty?
    raise InvalidSettings, 'Must specify at least one valid JIRA status'
  end
  settings.ancestor_branches.each do |branch, ancestor_branch|
    if ancestor_branch.blank?
      raise InvalidSettings, "Must specify an ancestor branch for #{branch}"
    end
  end
  if settings.deploy_types_for_repos.empty?
    raise InvalidSettings, 'Must specify at least one JIRA deploy type repository mapping'
  end
  settings.deploy_types_for_repos.each do |repo, deploy_types|
    if deploy_types.blank?
      raise InvalidSettings, "Must specify at least one deploy type for repository #{repo}"
    end
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

  validate_common_settings(settings_object)

  if settings_hash['jira']
    settings_object.jira = OpenStruct.new(DEFAULT_JIRA_SETTINGS.merge(settings_object.jira))
    validate_jira_settings(settings_object.jira)
  end

  settings_object
end

GlobalSettings = load_global_settings
