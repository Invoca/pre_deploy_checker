# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_10_25_185335) do

  create_table "branches", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.datetime "git_updated_at", null: false
    t.string "name", limit: 1024, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "author_id", null: false
    t.integer "repository_id", null: false
    t.index ["author_id"], name: "index_branches_on_author_id"
    t.index ["repository_id"], name: "index_branches_on_repository_id"
  end

  create_table "commits", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "sha", null: false
    t.text "message", limit: 4294967295, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "author_id", null: false
    t.integer "jira_issue_id"
    t.index ["author_id"], name: "index_commits_on_author_id"
    t.index ["jira_issue_id"], name: "index_commits_on_jira_issue_id"
  end

  create_table "commits_and_pushes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "errors_json", limit: 4294967295
    t.boolean "ignore_errors", default: false, null: false
    t.integer "push_id", null: false
    t.integer "commit_id", null: false
    t.boolean "no_jira", default: false, null: false
    t.index ["commit_id"], name: "index_commits_and_pushes_on_commit_id"
    t.index ["push_id"], name: "index_commits_and_pushes_on_push_id"
  end

  create_table "delayed_jobs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", limit: 4294967295, null: false
    t.text "last_error", limit: 4294967295
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "jira_issues", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "key", null: false
    t.string "issue_type", null: false
    t.text "summary", limit: 4294967295, null: false
    t.string "status", null: false
    t.date "targeted_deploy_date"
    t.string "post_deploy_check_status"
    t.string "deploy_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "assignee_id"
    t.integer "parent_issue_id"
    t.text "secrets_modified"
    t.string "long_running_migration"
    t.index ["assignee_id"], name: "index_jira_issues_on_assignee_id"
    t.index ["parent_issue_id"], name: "index_jira_issues_on_parent_issue_id"
  end

  create_table "jira_issues_and_pushes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.text "errors_json", limit: 4294967295
    t.boolean "ignore_errors", default: false, null: false
    t.integer "push_id", null: false
    t.integer "jira_issue_id", null: false
    t.boolean "merged", default: false, null: false
    t.index ["jira_issue_id"], name: "index_jira_issues_and_pushes_on_jira_issue_id"
    t.index ["push_id"], name: "index_jira_issues_and_pushes_on_push_id"
  end

  create_table "pushes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "status", limit: 32, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "head_commit_id", null: false
    t.integer "branch_id", null: false
    t.boolean "email_sent", default: false, null: false
    t.bigint "service_id", null: false
    t.index ["branch_id"], name: "index_pushes_on_branch_id"
    t.index ["head_commit_id"], name: "index_pushes_on_head_commit_id"
    t.index ["service_id"], name: "on_service_id"
  end

  create_table "repositories", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "services", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "ref", default: "master", null: false
    t.index ["name"], name: "on_name", unique: true
  end

  create_table "users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
