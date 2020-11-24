# frozen_string_literal: true

class Commit < ActiveRecord::Base
  fields do
    sha :string, limit: 40, index: true, unique: true,
      validates: { uniqueness: { message: 'SHAs must be globally unique' }, format: { without: /0{40}/ } }

    message :string, limit: 1024
    timestamps
  end

  belongs_to :author,     class_name: 'User',      inverse_of: :commits, optional: false
  belongs_to :jira_issue, class_name: 'JiraIssue', inverse_of: :commits, optional: true

  has_many :commits_and_pushes, class_name: 'CommitsAndPushes', inverse_of: :commit, dependent: :destroy
  has_many :pushes, through: :commits_and_pushes

  has_many :head_pushes, class_name: 'Push', inverse_of: :head_commit

  class << self
    def create_from_git_commit!(git_commit)
      where(sha: git_commit.sha).first_or_initialize.tap do |commit|
        commit.message = git_commit.message.truncate(1024)
        commit.author = User.find_or_create_by!(name: github_data.author_name, email: github_data.author_email)
        commit.save!
      end
    end
  end

  def message_contains_no_jira_tag?
    message.match?(/no[-,_,\s]?jira/i)
  end

  def short_sha
    sha[0, 7]
  end

  def to_s
    sha
  end

  def <=>(other)
    sha <=> other.sha
  end
end
