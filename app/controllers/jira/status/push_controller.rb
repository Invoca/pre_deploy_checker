module Jira
  module Status
    class PushController < ApplicationController
      ERROR_CODE_PLURAL_MAP = {
        'commit' => {
          CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER.to_s => 'Commit(s) with no JIRA issue number',
          CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND.to_s => 'Commit(s) with an unknown JIRA issue number'
        },
        'jira_issue' => {
          JiraIssuesAndPushes::ERROR_WRONG_STATE.to_s => 'JIRA issue(s) in the wrong state',
          JiraIssuesAndPushes::ERROR_NO_COMMITS.to_s => 'JIRA issue(s) with no commits',
          JiraIssuesAndPushes::ERROR_WRONG_DEPLOY_DATE.to_s => 'JIRA issue(s) with a deploy date in the past',
          JiraIssuesAndPushes::ERROR_NO_DEPLOY_DATE.to_s => 'JIRA issue(s) with no deploy date',
          JiraIssuesAndPushes::ERROR_POST_DEPLOY_CHECK_STATUS.to_s =>
            'JIRA issue(s) with the wrong post deploy check status',
          JiraIssuesAndPushes::ERROR_BLANK_SECRETS_MODIFIED.to_s => 'JIRA issue(s) with blank secrets fields',
          JiraIssuesAndPushes::ERROR_BLANK_LONG_RUNNING_MIGRATION.to_s => 'JIRA issue(s) with blank migration fields'
        }
      }.freeze
      ERROR_CODE_SINGULAR_MAP = {
        'commit' => {
          CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER.to_s => 'Has no JIRA issue number',
          CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND.to_s => 'Has an unknown JIRA issue number'
        },
        'jira_issue' => {
          JiraIssuesAndPushes::ERROR_WRONG_STATE.to_s => 'In the wrong state',
          JiraIssuesAndPushes::ERROR_NO_COMMITS.to_s => 'Has no commits',
          JiraIssuesAndPushes::ERROR_WRONG_DEPLOY_DATE.to_s => 'The deploy date in the past',
          JiraIssuesAndPushes::ERROR_NO_DEPLOY_DATE.to_s => 'Has no deploy date',
          JiraIssuesAndPushes::ERROR_POST_DEPLOY_CHECK_STATUS.to_s => 'Wrong post deploy check status',
          JiraIssuesAndPushes::ERROR_BLANK_SECRETS_MODIFIED.to_s => 'Secrets field is blank',
          JiraIssuesAndPushes::ERROR_BLANK_LONG_RUNNING_MIGRATION.to_s => 'Migrations field is blank'
        }
      }.freeze

      before_action :find_resources

      def edit
      end

      def update
        jira_issue_keys_to_ignore = []
        commit_shas_to_ignore = []
        if params['push']
          jira_issue_keys_to_ignore = params['push']['jira_issue_keys_to_ignore'] || []
          commit_shas_to_ignore = params['push']['commit_shas_to_ignore'] || []
        end

        updated_record_count = update_ignored_jira_issues(jira_issue_keys_to_ignore) + \
                               update_ignored_commits(commit_shas_to_ignore)

        if updated_record_count > 0
          flash[:alert] = 'Push updated, refreshing JIRA and Git data'
          PushChangeHandler.new.process_push!(@push.id)
        elsif params['refresh']
          flash[:alert] = 'Refreshing JIRA and Git data'
          PushChangeHandler.new.process_push!(@push.id)
        else
          flash[:alert] = 'No changes made'
        end
        redirect_to action: 'edit', id: @push.head_commit.sha
      end

      def github_url_for_commit(commit)
        "https://github.com/#{@push.branch.repository.name}/commit/#{commit.sha}"
      end
      helper_method :github_url_for_commit

      def jira_url_for_issue(jira_issue)
        "#{GlobalSettings.jira.site}/browse/#{jira_issue.key}"
      end
      helper_method :jira_url_for_issue

      def combined_error_counts
        error_counts = {}
        error_counts['jira_issue'] = JiraIssuesAndPushes.get_error_counts_for_push(@push)
        error_counts['commit'] = CommitsAndPushes.get_error_counts_for_push(@push)
        error_counts
      end
      helper_method :combined_error_counts

      def map_error_code_to_message(error_object, error_code)
        ERROR_CODE_PLURAL_MAP[error_object][error_code]
      end
      helper_method :map_error_code_to_message

      def jira_error_messages(error_list)
        error_list.collect do |error_code|
          ERROR_CODE_SINGULAR_MAP['jira_issue'][error_code]
        end.join(', ')
      end
      helper_method :jira_error_messages

      def commit_error_messages(error_list)
        error_list.collect do |error_code|
          ERROR_CODE_SINGULAR_MAP['commit'][error_code]
        end.join(', ')
      end
      helper_method :commit_error_messages

      def ancestor_branch
        PushManager.ancestor_branch_name(@push.branch.name)
      end
      helper_method :ancestor_branch

      def error_class_if_error_present(error_object, error_codes)
        has_error = error_codes.any? do |error_code|
          error_object.has_error?(error_code)
        end
        'error' if has_error
      end
      helper_method :error_class_if_error_present

      private

      def find_resources
        @push = Push.joins(:head_commit).where('commits.sha = ?', params[:id]).first!
      rescue ActiveRecord::RecordNotFound
        flash[:alert] = 'The push could not be found'
        redirect_to controller: '/errors', action: 'bad_request'
      end

      def update_ignored_jira_issues(jira_issue_keys_to_ignore)
        updated_record_count = 0
        @push.jira_issues_and_pushes.each do |jira_issue_and_push|
          jira_issue_and_push.ignore_errors = jira_issue_keys_to_ignore.include?(jira_issue_and_push.jira_issue.key)
          updated_record_count += 1 if jira_issue_and_push.changed?
          jira_issue_and_push.save!
        end
        updated_record_count
      end

      def update_ignored_commits(commit_shas_to_ignore)
        updated_record_count = 0
        @push.commits_and_pushes.each do |commit_and_push|
          commit_and_push.ignore_errors = commit_shas_to_ignore.include?(commit_and_push.commit.sha)
          updated_record_count += 1 if commit_and_push.changed?
          commit_and_push.save!
        end
        updated_record_count
      end
    end
  end
end
