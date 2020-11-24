# frozen_string_literal: true

class AddNoJiraToCommitsAndPushes < ActiveRecord::Migration[4.2]
  def self.up
    add_column :commits_and_pushes, :no_jira, :boolean, default: false, null: false
  end

  def self.down
    remove_column :commits_and_pushes, :no_jira
  end
end
