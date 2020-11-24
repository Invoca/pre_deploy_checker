class CommitsAndPushes < ActiveRecord::Base
  fields do
    no_jira :boolean, default: false
  end

  include ErrorsJson

  ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER = 'orphan_no_jira_issue_number'.freeze
  ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND = 'orphan_jira_issue_not_found'.freeze
  NO_JIRA_FOUND                     = 'No-Jira tag found'.freeze

  belongs_to :push,   inverse_of: :commits_and_pushes, optional: false
  belongs_to :commit, inverse_of: :commits_and_pushes, optional: false

  class << self
    def with_no_jira_tag
      where(no_jira: true)
    end

    def create_or_update!(commit, push, error_list = nil)
      CommitsAndPushes.find_or_initialize_by(commit: commit, push: push).tap do |record|
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

    # TODO: this can be cleaned up with scoping and Associa
    def get_error_counts_for_push(push)
      get_error_counts(with_unignored_errors.where(push: push))
    end

    # TODO: this might be refactorable
    def destroy_if_commit_not_in_list(push, commits)
      if commits.any?
        where(push: push).where('commit_id NOT IN (?)', commits).destroy_all
      else
        where(push: push).destroy_all
      end
    end
  end

  def copy_ignore_flag_from_most_recent_push
    if (previous_record = CommitsAndPushes.where(commit: commit).where.not(id: id).order('id desc').first)
      self.ignore_errors = previous_record.ignore_errors
    end
  end
end
