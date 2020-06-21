class JiraIssue < ActiveRecord::Base
  KEY_PROJECT_NUMBER_SEPARATOR = '-'.freeze

  fields do
    key :text, limit: 255, null: false
    issue_type :text, limit: 255, null: false
    summary :text, limit: 1024, null: false
    status :text, limit: 255, null: false
    targeted_deploy_date :date, null: true # Custom Data Field: 10600
    post_deploy_check_status :text, limit: 255, null: true
    deploy_type :text, limit: 255, null: true
    secrets_modified :text, limit: 255, null: true # deprecated
    long_running_migration :text, limit: 255, null: true
    timestamps
  end

  validates :key, uniqueness: { message: 'Keys must be globally unique' }
  validates :key, format: { with: /\A.+-[0-9]+\z/ }

  belongs_to :assignee, class_name: 'User', inverse_of: :commits, required: false
  belongs_to :parent_issue, class_name: 'JiraIssue', inverse_of: :sub_tasks, required: false
  has_many :sub_tasks, class_name: 'JiraIssue', dependent: :nullify
  has_many :commits, foreign_key: 'jira_issue_id', dependent: :nullify
  has_many :jira_issues_and_pushes, class_name: 'JiraIssuesAndPushes', inverse_of: :jira_issue, dependent: :destroy
  has_many :pushes, through: :jira_issues_and_pushes

  def commits_for_push(push)
    commits.joins(:commits_and_pushes).where('commits_and_pushes.push_id = ?', push.id)
  end

  def long_running_migration?
    long_running_migration && long_running_migration == 'Yes'
  end

  def deploy_types
    if deploy_type
      deploy_type.split(',').map(&:strip).compact
    else
      []
    end
  end

  def jira_url_for_issue
    "#{Rails.application.secrets.jira[:'site']}/browse/#{key}"
  end

  class << self
    def create_from_jira_data!(jira_client, jira_data)
      issue = create_from_jira_data(jira_client, jira_data)
      issue.save!
      issue
    end

    def create_from_jira_data(jira_client, jira_data)
      issue = JiraIssue.where(key: jira_data.key).first_or_initialize
      issue.summary = jira_data.summary.truncate(1024)
      issue.issue_type = jira_data.issuetype.name
      issue.status = jira_data.fields['status']['name']
      issue.post_deploy_check_status = extract_custom_select_field_from_jira_data(jira_data, 12202)
      issue.deploy_type = extract_custom_multi_select_field_from_jira_data(jira_data, 12501)
      issue.long_running_migration = extract_custom_multi_select_field_from_jira_data(jira_data, 10601)

      if jira_data.assignee
        issue.assignee = User.create_from_jira_data!(jira_client, jira_data.assignee)
      end

      if jira_data.respond_to?(:parent)
        issue.parent_issue = create_from_jira_data!(jira_client, JIRA::Resource::IssueFactory.new(jira_client).build(jira_data.parent))
      end

      issue
    end

    private

    def extract_custom_select_field_from_jira_data(jira_data, field_number)
      field_name = "customfield_#{field_number}"
      if jira_data.fields[field_name]
        jira_data.fields[field_name]['value']
      end
    end

    def extract_custom_date_field_from_jira_data(jira_data, field_number)
      field_name = "customfield_#{field_number}"
      if jira_data.fields[field_name]
        Date.parse(jira_data.fields[field_name])
      end
    end

    def extract_custom_multi_select_field_from_jira_data(jira_data, field_number)
      field_name = "customfield_#{field_number}"
      if jira_data.fields[field_name] # rubocop:disable Style/SafeNavigation
        jira_data.fields[field_name].collect do |value|
          value['value']
        end.join ', '
      end
    end
  end

  def <=>(other)
    if parent_issue && other.parent_issue
      compare_parent_keys(other)
    elsif parent_issue
      parent_issue <=> other
    elsif other.parent_issue
      self <=> other.parent_issue
    else
      compare_keys(other)
    end
  end

  def project
    key.split(KEY_PROJECT_NUMBER_SEPARATOR)[0]
  end

  def number
    key.split(KEY_PROJECT_NUMBER_SEPARATOR)[1].to_i
  end

  def compare_keys(other)
    if project == other.project
      number <=> other.number
    else
      project <=> other.project
    end
  end

  def compare_parent_keys(other)
    if parent_issue.key == other.parent_issue.key
      compare_keys(other)
    else
      parent_issue <=> other.parent_issue
    end
  end

  def latest_commit
    # TODO: add commit date to commits and sort by that instead
    commits.order('created_at ASC').first
  end

  def sub_task?
    !!parent_issue
  end
end
