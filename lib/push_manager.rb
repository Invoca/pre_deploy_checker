class PushManager
  class << self
    def process_push!(push)
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
      jira_issues = get_jira_issues!(all_issue_keys)

      # get issues from JIRA that should have been in the commits, but were not
      unrelated_jira_issues = get_other_jira_issues_in_valid_states(push, all_issue_keys)
      Rails.logger.info(
        "Found #{unrelated_jira_issues.length} JIRA issues that are in valid states but not in push id #{push.id}"
      )
      jira_issues += unrelated_jira_issues

      link_commits_to_jira_issues(jira_issues, commits)

      link_jira_issues_to_push(push, jira_issues)

      # destroy relationship to commits that are no longer in the push
      CommitsAndPushes.destroy_if_commit_not_in_list(push, commits)

      # assume that issues that have commits related to them, but are no longer found in the commits for this push, have been merged to the ancestor branch
      merged_jira_issues = jira_issues.select { |j| !issue_keys_from_commits.include?(j.key) && j.commits.any? }
      JiraIssuesAndPushes.mark_as_merged(push, merged_jira_issues)

      push.reload

      # detect errors in the commit and pushes
      detect_errors_for_linked_jira_issues(push)
      detect_errors_for_linked_commits(push)

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

    def valid_jira_state?(status)
      GlobalSettings.jira.valid_statuses.any? { |valid_status| valid_status.casecmp(status).zero? }
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

    def get_jira_issues!(issue_keys)
      jira_client = JIRA::ClientWrapper.new(Rails.application.secrets.jira)
      issue_keys.collect do |ticket_number|
        issue = jira_client.find_issue_by_key(ticket_number)
        if issue
          JiraIssue.create_from_jira_data!(issue)
        end
      end.compact
    end

    # how to prevent shipped pushes from picking up issues that are not in the branch!?!
    # targeted deploy date?
    # don't poll for issues with no commits when the branch contains no commits?
    def get_other_jira_issues_in_valid_states(push, issue_keys)
      quoted_statuses = GlobalSettings.jira.valid_statuses.map do |status|
        "\"#{status}\""
      end
      jql = "status IN (#{quoted_statuses.join(', ')}) " \
            "AND project IN (#{GlobalSettings.jira.project_keys.join(', ').upcase}) " \
            "AND customfield_12501 IN (#{GlobalSettings.jira.deploy_types_for_repos[push.branch.repository.name].join(', ')})"

      if issue_keys.any?
        jql += " AND key NOT IN (#{issue_keys.join(', ')})"
      end
      jira_client = JIRA::ClientWrapper.new(Rails.application.secrets.jira)
      jira_client.find_issues_by_jql(jql).collect do |issue|
        JiraIssue.create_from_jira_data!(issue)
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
      unless valid_jira_state?(jira_issue.status)
        errors << JiraIssuesAndPushes::ERROR_WRONG_STATE
      end

      unless valid_post_deploy_check_status?(jira_issue.post_deploy_check_status)
        errors << JiraIssuesAndPushes::ERROR_POST_DEPLOY_CHECK_STATUS
      end

      if jira_issue.commits_for_push(push).empty? && !jira_issue.is_merged_in_push?(push)
        errors << JiraIssuesAndPushes::ERROR_NO_COMMITS
      end

      if jira_issue.targeted_deploy_date
        if jira_issue.targeted_deploy_date.to_date < Time.zone.today
          errors << JiraIssuesAndPushes::ERROR_WRONG_DEPLOY_DATE
        end
      else
        errors << JiraIssuesAndPushes::ERROR_NO_DEPLOY_DATE
      end

      unless jira_issue.secrets_modified
        errors << JiraIssuesAndPushes::ERROR_BLANK_SECRETS_MODIFIED
      end

      unless jira_issue.long_running_migration
        errors << JiraIssuesAndPushes::ERROR_BLANK_LONG_RUNNING_MIGRATION
      end

      errors
    end

    def link_commits_to_push(push, commits)
      commits.each do |commit|
        CommitsAndPushes.create_or_update!(commit, push)
      end
    end

    def detect_errors_for_linked_commits(push)
      push.commits_and_pushes.each do |commit_and_push|
        commit_and_push.error_list = detect_errors_for_commit(commit_and_push.commit)
        commit_and_push.save!
      end
    end

    def detect_errors_for_commit(commit)
      errors = []
      unless commit.jira_issue(true)
        errors << if commit.message.match(jira_issue_regexp)
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
