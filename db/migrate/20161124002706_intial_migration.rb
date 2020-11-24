# frozen_string_literal: true

class IntialMigration < ActiveRecord::Migration[4.2]
  def self.up
    create_table :commits_and_pushes do |t|
      t.string  :errors_json, :limit => 256, :required => false
      t.boolean :ignore_errors, :default => false, :required => true
      t.integer :push_id
      t.integer :commit_id
    end
    add_index :commits_and_pushes, [:push_id]
    add_index :commits_and_pushes, [:commit_id]

    create_table :jira_issues_and_pushes do |t|
      t.string  :errors_json, :limit => 256, :required => false
      t.boolean :ignore_errors, :default => false, :required => true
      t.integer :push_id
      t.integer :jira_issue_id
    end
    add_index :jira_issues_and_pushes, [:push_id]
    add_index :jira_issues_and_pushes, [:jira_issue_id]

    create_table :branches do |t|
      t.datetime :git_updated_at, :null => false
      t.text     :name, :limit => 1024, :null => false
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :author_id
      t.integer  :repository_id
    end
    add_index :branches, [:author_id]
    add_index :branches, [:repository_id]

    create_table :users do |t|
      t.text     :name, :limit => 255, :null => false
      t.text     :email, :limit => 255, :null => false
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :commits do |t|
      t.text     :sha, :limit => 40, :null => false
      t.text     :message, :limit => 1024, :null => false
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :author_id
      t.integer  :jira_issue_id
    end
    add_index :commits, [:author_id]
    add_index :commits, [:jira_issue_id]

    create_table :jira_issues do |t|
      t.text     :key, :limit => 255, :null => false
      t.text     :issue_type, :limit => 255, :null => false
      t.text     :summary, :limit => 1024, :null => false
      t.text     :status, :limit => 255, :null => false
      t.date     :targeted_deploy_date
      t.text     :post_deploy_check_status, :limit => 255
      t.text     :deploy_type, :limit => 255
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :assignee_id
      t.integer  :parent_issue_id
    end
    add_index :jira_issues, [:assignee_id]
    add_index :jira_issues, [:parent_issue_id]

    create_table :repositories do |t|
      t.text     :name, :limit => 1024, :null => false
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :pushes do |t|
      t.string   :status, :limit => 32
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :head_commit_id
      t.integer  :branch_id
    end
    add_index :pushes, [:head_commit_id]
    add_index :pushes, [:branch_id]
  end

  def self.down
    drop_table :commits_and_pushes
    drop_table :jira_issues_and_pushes
    drop_table :branches
    drop_table :users
    drop_table :commits
    drop_table :jira_issues
    drop_table :repositories
    drop_table :pushes
  end
end
