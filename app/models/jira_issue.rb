# frozen_string_literal: true

class JiraIssue < ActiveRecord::Base
  KEY_PROJECT_NUMBER_SEPARATOR = '-'

  fields do
    key                      :string, limit: 255, index: true, unique: true,
                               validates: { uniqueness: { message: 'Keys must be globally unique' }, format: { with: /\A.+-[0-9]+\z/ } }
    issue_type               :string, limit: 255
    summary                  :text, limit: 0xffff_ffff
    status                   :string, limit: 255
    targeted_deploy_date     :date, null: true # Custom Data Field: 10600
    post_deploy_check_status :string, limit: 255, null: true
    deploy_type              :string, limit: 255, null: true
    secrets_modified         :text, limit: 0xffff, null: true # deprecated
    long_running_migration   :string, limit: 255, null: true

    timestamps
  end

  belongs_to :assignee,     class_name: 'User', inverse_of: :issues, optional: true
  belongs_to :parent_issue, class_name: 'JiraIssue', inverse_of: :sub_tasks, optional: true

  has_many :sub_tasks, class_name: 'JiraIssue', inverse_of: :parent_issue, dependent: :nullify
  has_many :commits, inverse_of: :jira_issue, dependent: :nullify
  has_many :jira_issues_and_pushes, inverse_of: :jira_issue, dependent: :destroy
  has_many :pushes, through: :jira_issues_and_pushes

  class << self
    def create_from_jira_data!(jira_data)
      transaction do
        create_from_jira_data(jira_data).tap { |issue| issue.save! }
      end
    end

    def create_from_jira_data(jira_data)
      transaction do
        JiraIssue.find_or_initialize_by(key: jira_data.key).tap do |issue|
          issue.summary = jira_data.summary.truncate(1024)
          issue.issue_type = jira_data.issuetype.name
          issue.status = jira_data.fields.dig('status', 'name')
          issue.post_deploy_check_status = extract_custom_select_field_from_jira_data(jira_data, 12202)
          issue.deploy_type = extract_custom_multi_select_field_from_jira_data(jira_data, 12501)
          issue.long_running_migration = extract_custom_multi_select_field_from_jira_data(jira_data, 10601)

          if jira_data.assignee
            issue.assignee = User.create_from_jira_data!(jira_data.assignee)
          end

          if (parent_data = jira_data.try(:parent))
            issue.parent_issue = create_from_jira_data!(JIRA::Resource::IssueFactory.new(nil).build(parent_data))
          end
        end
      end
    end

    private

    def extract_custom_select_field_from_jira_data(jira_data, field_number)
      field_name = "customfield_#{field_number}"
      jira_data.dig(field_name, 'value')
    end

    def extract_custom_date_field_from_jira_data(jira_data, field_number)
      field_name = "customfield_#{field_number}"
      if (date = jira_data.fields[field_name])
        Date.parse(date)
      end
    end

    def extract_custom_multi_select_field_from_jira_data(jira_data, field_number)
      field_name = "customfield_#{field_number}"
      if (field_values = jira_data.fields[field_name])
        field_values.map { |value| value['value'] }.join(', ')
      end
    end
  end

  def commits_for_push(push)
    commits.joins(:commits_and_pushes).where(commits_and_pushes: { push_id: push.id })
  end

  def long_running_migration?
    long_running_migration == 'Yes'
  end

  # TODO: This should use Rails Serialization
  def deploy_types
    if deploy_type
      deploy_type.split(',').map_compact(&:strip)
    else
      []
    end
  end

  def jira_url_for_issue
    "#{Rails.application.secrets.jira[:site]}/browse/#{key}"
  end

  # TODO: Refactor this for easier readability
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

  def compare_parent_keys(other)
    if parent_issue.key == other.parent_issue.key
      compare_keys(other)
    else
      parent_issue <=> other.parent_issue
    end
  end

  def compare_keys(other)
    if project == other.project
      number <=> other.number
    else
      project <=> other.project
    end
  end

  def project
    key.split(KEY_PROJECT_NUMBER_SEPARATOR)[0]
  end

  def number
    key.split(KEY_PROJECT_NUMBER_SEPARATOR)[1].to_i
  end

  def latest_commit
    # TODO: add commit date to commits and sort by that instead
    commits.order('created_at ASC').first
  end

  def sub_task?
    !!parent_issue
  end
end
