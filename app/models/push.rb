# frozen_string_literal: true

class Push < ActiveRecord::Base
  fields do
    status       :string,  limit: 32, validates: { inclusion: Github::Api::Status::STATES.map(&:to_s) }
    email_sent   :boolean, default: false

    timestamps
  end

  has_many :commits_and_pushes, class_name: :CommitsAndPushes, inverse_of: :push, dependent: :destroy
  has_many :commits, through: :commits_and_pushes
  has_many :jira_issues_and_pushes, class_name: :JiraIssuesAndPushes, inverse_of: :push, dependent: :destroy
  has_many :jira_issues, through: :jira_issues_and_pushes
  has_many :service, inverse_of: :pushes

  belongs_to :head_commit, class_name: 'Commit', inverse_of: :head_pushes, optional: false
  belongs_to :branch, inverse_of: :pushes, optional: false

  class << self
    def create_from_github_data!(github_data)
      transaction do
        commit = Commit.create_from_git_commit!(github_data)
        branch = Branch.create_from_git_data!(github_data.git_branch_data)
        # TODO: Service should map to repo and push should map to repo for this association tree
        Service.all.map do |service|
          push = Push.find_or_initialize_by(head_commit: commit, branch: branch, service: service)
          push.status = Github::Api::Status::STATE_PENDING
          push.save!
          CommitsAndPushes.create_or_update!(commit, push)
          # TODO: this is a code smell, we should figure this out and remove it
          push.reload
        end
      end
    end

    def with_jira_issue(key)
      joins(:jira_issues).where(jira_issues: { key: key })
    end

    def for_service(service_name)
      joins(:service).where(services: { name: service_name })
    end

    def for_commit_and_service(commit, service_name)
      joins(:head_commit, :service).where(commits: { sha: commit }, services: { name: service_name })
    end
  end

  delegate :name, to: :service, prefix: true

  def to_s
    "#{branch.name}/#{head_commit.sha}"
  end

  def jira_issues?
    jira_issues.any?
  end

  def jira_issue_keys
    jira_issues.map(&:key)
  end

  def jira_issues_with_errors?
    jira_issues_with_errors.any?
  end

  def jira_issues_with_errors
    jira_issues_and_pushes.with_errors
  end

  def jira_issues_with_unignored_errors?
    jira_issues_and_pushes.with_unignored_errors.any?
  end

  def commits_with_errors?
    commits_with_errors.any?
  end

  def commits_with_unignored_errors?
    commits_with_errors.with_unignored_errors.any?
  end

  def commits_with_errors
    commits_and_pushes.with_errors
  end

  def no_jira_commits
    commits_and_pushes.with_no_jira_tag
  end

  def no_jira_commits?
    no_jira_commits.any?
  end

  def errors?
    commits_with_errors? || jira_issues_with_errors?
  end

  def error_counts
    {
      'jira_issue' => jira_issues_and_pushes.with_unignored_errors.error_counts,
      'commit'     => commits_and_pushes.with_unignored_errors.error_counts
    }
  end

  # TODO: This is a lot of knowledge of Jira Issues in the Push class
  #       we should move this over to jira issues and use it there.
  def unmerged_jira_issues
    jira_issues_and_pushes.where(merged: false).map(&:jira_issue)
  end

  def deploy_types
    jira_issues.map(&:deploy_types).flatten.uniq
  end

  def long_migration?
    unmerged_jira_issues.any?(&:long_running_migration?)
  end

  def sorted_jira_issues
    unmerged_jira_issues.sort_by(&:key).reverse
  end

  def <=>(other)
    to_s <=> other.to_s
  end

  def compute_status!
    self.status = if commits_with_unignored_errors? || jira_issues_with_unignored_errors?
                    Github::Api::Status::STATE_FAILED
                  else
                    Github::Api::Status::STATE_SUCCESS
                  end
  end
end
