# frozen_string_literal: true

class PreserveMergedJiraIssues < ActiveRecord::Migration[4.2]
  def self.up
    add_column :jira_issues_and_pushes, :merged, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :jira_issues_and_pushes, :merged
  end
end
