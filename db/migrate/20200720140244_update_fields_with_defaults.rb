# frozen_string_literal: true

class UpdateFieldsWithDefaults < ActiveRecord::Migration[4.2]
  def self.up
    change_column :commits_and_pushes, :errors_json, :string, :limit => 256, :null => true
    change_column :commits_and_pushes, :ignore_errors, :boolean, :null => false, :default => false
    change_column :commits_and_pushes, :push_id, :integer, :limit => nil, :null => false
    change_column :commits_and_pushes, :commit_id, :integer, :limit => nil, :null => false

    change_column :jira_issues_and_pushes, :errors_json, :string, :limit => 256, :null => true
    change_column :jira_issues_and_pushes, :ignore_errors, :boolean, :null => false, :default => false
    change_column :jira_issues_and_pushes, :push_id, :integer, :limit => nil, :null => false
    change_column :jira_issues_and_pushes, :jira_issue_id, :integer, :limit => nil, :null => false

    change_column :branches, :name, :text, :limit => 3072, :null => false
    change_column :branches, :author_id, :integer, :limit => nil, :null => false
    change_column :branches, :repository_id, :integer, :limit => nil, :null => false

    change_column :pushes, :status, :string, :limit => 32, :null => false
    change_column :pushes, :head_commit_id, :integer, :limit => nil, :null => false
    change_column :pushes, :branch_id, :integer, :limit => nil, :null => false
    change_column :pushes, :email_sent, :boolean, :null => false, :default => false

    change_column :commits, :sha, :text, :limit => 120, :null => false
    change_column :commits, :message, :text, :limit => 3072, :null => false
    change_column :commits, :author_id, :integer, :limit => nil, :null => false

    change_column :jira_issues, :key, :text, :limit => 765, :null => false
    change_column :jira_issues, :issue_type, :text, :limit => 765, :null => false
    change_column :jira_issues, :summary, :text, :limit => 3072, :null => false
    change_column :jira_issues, :status, :text, :limit => 765, :null => false
    change_column :jira_issues, :post_deploy_check_status, :text, :limit => 765
    change_column :jira_issues, :deploy_type, :text, :limit => 765
    change_column :jira_issues, :secrets_modified, :text, :limit => 765
    change_column :jira_issues, :long_running_migration, :text, :limit => 765

    change_column :users, :name, :text, :limit => 765, :null => false
    change_column :users, :email, :text, :limit => 765, :null => false

    change_column :repositories, :name, :text, :limit => 3072, :null => false
  end

  def self.down
    change_column :commits_and_pushes, :errors_json, :string, limit: 256
    change_column :commits_and_pushes, :ignore_errors, :boolean, default: false
    change_column :commits_and_pushes, :push_id, :integer
    change_column :commits_and_pushes, :commit_id, :integer

    change_column :jira_issues_and_pushes, :errors_json, :string, limit: 256
    change_column :jira_issues_and_pushes, :ignore_errors, :boolean, default: false
    change_column :jira_issues_and_pushes, :push_id, :integer
    change_column :jira_issues_and_pushes, :jira_issue_id, :integer

    change_column :branches, :name, :text, limit: 1024, null: false
    change_column :branches, :author_id, :integer
    change_column :branches, :repository_id, :integer

    change_column :pushes, :status, :string, limit: 32
    change_column :pushes, :head_commit_id, :integer
    change_column :pushes, :branch_id, :integer
    change_column :pushes, :email_sent, :boolean, default: false

    change_column :commits, :sha, :text, limit: 40,   null: false
    change_column :commits, :message, :text, limit: 1024, null: false
    change_column :commits, :author_id, :integer

    change_column :jira_issues, :key, :text, limit: 255,  null: false
    change_column :jira_issues, :issue_type, :text, limit: 255,  null: false
    change_column :jira_issues, :summary, :text, limit: 1024, null: false
    change_column :jira_issues, :status, :text, limit: 255,  null: false
    change_column :jira_issues, :post_deploy_check_status, :text, limit: 255
    change_column :jira_issues, :deploy_type, :text, limit: 255
    change_column :jira_issues, :secrets_modified, :text, limit: 255
    change_column :jira_issues, :long_running_migration, :text, limit: 255

    change_column :users, :name, :text, limit: 255, null: false
    change_column :users, :email, :text, limit: 255, null: false

    change_column :repositories, :name, :text, limit: 1024, null: false
  end
end
