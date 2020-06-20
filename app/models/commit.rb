class Commit < ActiveRecord::Base
  include GitModels::Commit

  belongs_to :jira_issue, class_name: 'JiraIssue', inverse_of: :commits, required: false

  has_many :commits_and_pushes, class_name: 'CommitsAndPushes', inverse_of: :commit, dependent: :destroy
  has_many :pushes, through: :commits_and_pushes

  def self.create_from_github_data!(github_data)
    commit = Commit.where(sha: github_data.sha).first_or_initialize
    commit.message = github_data.message.truncate(1024)
    commit.author = User.create_from_git_data!(github_data.git_branch_data)
    commit.save!
    commit
  end

  def message_contains_no_jira_tag?
    message.downcase.match?(/no[-,_,\s]jira/)
  end
end
