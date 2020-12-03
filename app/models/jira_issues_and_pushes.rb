# frozen_string_literal: true

class JiraIssuesAndPushes < ActiveRecord::Base
  include ErrorsJson

  ERROR_WRONG_STATE = 'wrong_state'
  ERROR_POST_DEPLOY_CHECK_STATUS = 'wrong_post_deploy_status'
  ERROR_NO_COMMITS = 'no_commits'
  ERROR_BLANK_LONG_RUNNING_MIGRATION = 'blank_long_running_migration'

  fields do
    merged :boolean, default: false
  end

  belongs_to :push, inverse_of: :jira_issues_and_pushes, optional: false
  belongs_to :jira_issue, inverse_of: :jira_issues_and_pushes, optional: false

  class << self
    def merged
      where(merged: true)
    end

    def not_merged
      where(merged: false)
    end

    def create_or_update!(jira_issue, push, error_list = nil)
      JiraIssuesAndPushes.find_or_initialize_by(jira_issue: jira_issue, push: push).tap do |record|
        # preserve existing errors if not specified
        if error_list
          record.error_list = error_list
        end
        # if this is a newly created relationship, copy the ignore flag from the most recent relationship
        unless record.id
          record.copy_ignore_flag_from_most_recent_push
        end
        record.save!
      end
    end

    def mark_all_as_merged(push)
      where(push: push).update_all(merged: true)
    end

    def destroy_if_jira_issue_not_in_list(push, jira_issues)
      jira_issues_not_in_list(push, jira_issues).destroy_all
    end

    def jira_issues_not_in_list(push, jira_issues)
      if jira_issues.any?
        where(push: push).where('jira_issue_id NOT IN (?)', jira_issues)
      else
        where(push: push)
      end
    end
  end

  def commits
    jira_issue.commits_for_push(push)
  end

  def copy_ignore_flag_from_most_recent_push
    previous_record = JiraIssuesAndPushes.where(jira_issue: jira_issue).where.not(id: id).order('id desc').first
    if previous_record
      self.ignore_errors = previous_record.ignore_errors
    end
  end

  def <=>(other)
    if push == other.push
      jira_issue <=> other.jira_issue
    else
      push <=> other.push
    end
  end
end
