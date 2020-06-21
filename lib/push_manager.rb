class PushManager
  class << self
    def process_push!(jira_client, push)
      push.status = Github::Api::Status::STATE_PENDING
      push.save!

      Rails.logger.info("Getting commits for push id #{push.id}")
      commits = get_commits_from_push(push)

      issue_keys_from_commits = extract_jira_issue_keys(commits)
      # we include the keys from existing issues on the push so we can update
      # issues for merged commits when they change
      all_issue_keys = (issue_keys_from_commits + push.jira_issue_keys).uniq

      link_commits_to_push(push, commits)

      Rails.logger.info("Getting #{all_issue_keys.length} JIRA issues for push id #{push.id}")
      jira_issues = get_jira_issues!(jira_client, all_issue_keys)

      link_commits_to_jira_issues(jira_issues, commits)

      link_jira_issues_to_push(push, jira_issues)

      # destroy relationship to commits that are no longer in the push
      CommitsAndPushes.destroy_if_commit_not_in_list(push, commits)

      # assume that issues no longer found in the commits have been merged to the ancestor branch
      jira_issues_from_commits = jira_issues.select { |j| issue_keys_from_commits.include?(j.key) }
      JiraIssuesAndPushes.mark_as_merged_if_jira_issue_not_in_list(push, jira_issues_from_commits)

      push.reload

      # detect errors in the commit and pushes
      detect_errors_for_linked_jira_issues(push)
      detect_missing_jira_issues_for_linked_commits(push)

      # compute status
      push.compute_status!
      push.save!
      push
    end

    def ancestor_branch_name(branch_name)
      GlobalSettings.jira.ancestor_branches[branch_name] || GlobalSettings.jira.ancestor_branches['default']
    end

    private

    def jira_issue_regexp
      /(?:^|\s|\/|_|-|"|')((?:#{GlobalSettings.jira.project_keys.join('|')})[- _]\d+)/i
    end

    def valid_jira_status?(jira_issue)
      if jira_issue.sub_task?
        GlobalSettings.jira.valid_sub_task_statuses
      else
        GlobalSettings.jira.valid_statuses
      end.any? { |valid_status| valid_status.casecmp(jira_issue.status).zero? }
    end

    def valid_post_deploy_check_status?(status)
      if status
        GlobalSettings.jira.valid_post_deploy_check_statuses.any? { |valid_status| valid_status.casecmp(status).zero? }
      else
        false
      end
    end

    def extract_jira_issue_keys(commits)
      commits.collect do |commit|
        extract_jira_issue_key(commit)
      end.compact.uniq
    end

    def extract_jira_issue_key(commit)
      match = commit.message.match(jira_issue_regexp)
      if match
        match.captures[0].upcase.sub(/[ _]/, '-')
      end
    end

    def get_jira_issues!(jira_client, issue_keys)
      jira_client = JIRA::ClientWrapper.new(Rails.application.secrets.jira)
      issue_keys.collect do |ticket_number|
        issue = jira_client.find_issue_by_key(ticket_number)
        if issue
          JiraIssue.create_from_jira_data!(jira_client, issue)
        end
      end.compact
    end

    def link_commits_to_jira_issues(jira_issues, commits)
      jira_issues.each do |jira_issue|
        commits.each do |commit|
          if extract_jira_issue_key(commit) == jira_issue.key
            jira_issue.commits << commit
          end
        end
        jira_issue.save!
      end
    end

    def link_jira_issues_to_push(push, jira_issues)
      jira_issues.each do |jira_issue|
        JiraIssuesAndPushes.create_or_update!(jira_issue, push)
      end
    end

    def detect_errors_for_linked_jira_issues(push)
      push.jira_issues_and_pushes.each do |jira_issue_and_push|
        jira_issue_and_push.error_list = detect_errors_for_un_merged_jira_issue(push, jira_issue_and_push)
        jira_issue_and_push.save!
      end
    end

    def detect_errors_for_un_merged_jira_issue(push, jira_issue_and_push)
      if jira_issue_and_push.merged
        []
      else
        detect_errors_for_jira_issue(push, jira_issue_and_push.jira_issue)
      end
    end

    def detect_errors_for_jira_issue(push, jira_issue)
      errors = []
      unless valid_jira_status?(jira_issue)
        errors << JiraIssuesAndPushes::ERROR_WRONG_STATE
      end

      unless jira_issue.sub_task?
        unless valid_post_deploy_check_status?(jira_issue.post_deploy_check_status)
          errors << JiraIssuesAndPushes::ERROR_POST_DEPLOY_CHECK_STATUS
        end

        if jira_issue.commits_for_push(push).empty?
          errors << JiraIssuesAndPushes::ERROR_NO_COMMITS
        end

        unless jira_issue.long_running_migration
          errors << JiraIssuesAndPushes::ERROR_BLANK_LONG_RUNNING_MIGRATION
        end
      end

      errors
    end

    def link_commits_to_push(push, commits)
      commits.each do |commit|
        CommitsAndPushes.create_or_update!(commit, push)
      end
    end

    def detect_missing_jira_issues_for_linked_commits(push)
      push.commits_and_pushes.each do |commit_and_push|
        if commit_and_push.commit.message_contains_no_jira_tag?
          commit_and_push.no_jira = true
        else
          commit_and_push.error_list = detect_errors_for_commit(commit_and_push.commit)
        end

        commit_and_push.save!
      end
    end

    def detect_errors_for_commit(commit)
      errors = []
      unless commit.jira_issue(true)
        errors << if commit.message.match?(jira_issue_regexp)
                    CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND
                  else
                    CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER
                  end
      end

      errors
    end

    def get_commits_from_push(push)
      git = Git::Git.new(push.branch.repository.name, git_cache_path: GlobalSettings.cache_directory)
      git.clone_repository(GlobalSettings.jira.ancestor_branches['default'])
      git.commit_diff_refs(
        push.head_commit.sha,
        ancestor_branch_name(push.branch.name),
        fetch: true
      ).collect do |git_commit|
        next if GlobalSettings.jira.ignore_commits_with_messages.include_regexp?(
          git_commit.message,
          regexp_options: Regexp::IGNORECASE
        )

        Commit.create_from_git_commit!(git_commit)
      end.compact
    end
  end
end
