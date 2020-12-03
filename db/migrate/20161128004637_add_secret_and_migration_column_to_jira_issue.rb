# frozen_string_literal: true

class AddSecretAndMigrationColumnToJiraIssue < ActiveRecord::Migration[4.2]
  def self.up
    add_column :jira_issues, :secrets_modified, :text, :limit => 255
    add_column :jira_issues, :long_running_migration, :text, :limit => 255
  end

  def self.down
    remove_column :jira_issues, :secrets_modified
    remove_column :jira_issues, :long_running_migration
  end
end
