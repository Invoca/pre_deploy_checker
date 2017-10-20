require 'spec_helper'

describe 'PushManager' do
  def payload
    @payload ||= Github::Api::PushHookPayload.new(load_json_fixture('github_push_payload'))
  end

  def json_jira_issues(keys)
    keys.collect do |key|
      create_test_jira_issue_json(key: key, status: 'Ready to Deploy')
    end || []
  end

  def mock_jira_find_issue_response(key,
                                    status: 'Ready to Deploy',
                                    targeted_deploy_date: Time.current.tomorrow,
                                    post_deploy_check_status: 'Ready to Run',
                                    secrets_modified: 'No',
                                    long_running_migration: 'No')
    response = create_test_jira_issue_json(
      key: key,
      status: status,
      targeted_deploy_date: targeted_deploy_date,
      post_deploy_check_status: post_deploy_check_status,
      secrets_modified: secrets_modified,
      long_running_migration: long_running_migration
    )
    stub_request(:get, /\/rest\/api\/2\/issue\/#{key}/).to_return(status: 200, body: response.to_json)
  end

  def mock_jira_jql_response(keys)
    response = {
      'issues' => json_jira_issues(keys)
    }
    stub_request(:get, /\/rest\/api\/2\/search\?jql.*/).to_return(status: 200, body: response.to_json)
  end

  it 'can create jira issues, commits, and link them together' do
    commits = [Git::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha, message: 'STORY-1234 Description1'),
               Git::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha, message: 'STORY-5678 Description2')]
    expect_any_instance_of(Git::Git).to receive(:clone_repository)
    expect_any_instance_of(Git::Git).to receive(:commit_diff_refs).and_return(commits)

    ['STORY-1234', 'STORY-5678'].each do |key|
      mock_jira_find_issue_response(key)
      mock_jira_jql_response([])
    end
    push = PushManager.process_push!(Push.create_from_github_data!(payload))
    expect(push.commits.count).to eq(2)
    expect(push.commits[0].sha).to eq(commits[0].sha)
    expect(push.commits[1].sha).to eq(commits[1].sha)

    expect(push.jira_issues.count).to eq(2)
    expect(push.jira_issues[0].key).to eq('STORY-1234')
    expect(push.jira_issues[1].key).to eq('STORY-5678')

    push.jira_issues.each do |jira_issue|
      expect(jira_issue.commits.count).to eq(1)
    end
    expect(push.jira_issues[0].commits[0].sha).to eq(commits[0].sha)
    expect(push.jira_issues[1].commits[0].sha).to eq(commits[1].sha)
  end

  context 'detect jira_issue errors' do
    context 'with commits' do
      before do
        expect_any_instance_of(Git::Git).to receive(:clone_repository)
        expect_any_instance_of(Git::Git).to \
          receive(:commit_diff_refs).and_return([Git::TestHelpers.create_commit(message: 'STORY-1234 Description')])
        mock_jira_jql_response([])
      end

      it 'in the wrong state' do
        mock_jira_find_issue_response('STORY-1234', status: 'Wrong State')
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.jira_issues_and_pushes.first.error_list).to \
          match_array([JiraIssuesAndPushes::ERROR_WRONG_STATE])
      end

      it 'with the wrong post deploy check status' do
        mock_jira_find_issue_response('STORY-1234', post_deploy_check_status: 'Wrong Status')
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.jira_issues_and_pushes.first.error_list).to \
          match_array([JiraIssuesAndPushes::ERROR_POST_DEPLOY_CHECK_STATUS])
      end

      it 'with no post deploy check status' do
        mock_jira_find_issue_response('STORY-1234', post_deploy_check_status: nil)
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.jira_issues_and_pushes.first.error_list).to \
          match_array([JiraIssuesAndPushes::ERROR_POST_DEPLOY_CHECK_STATUS])
      end

      it 'without a deploy date' do
        mock_jira_find_issue_response('STORY-1234', targeted_deploy_date: nil)
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.jira_issues_and_pushes.first.error_list).to \
          match_array([JiraIssuesAndPushes::ERROR_NO_DEPLOY_DATE])
      end

      it 'with a deploy date in the past' do
        mock_jira_find_issue_response('STORY-1234', targeted_deploy_date: Time.current.yesterday)
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.jira_issues_and_pushes.first.error_list).to \
          match_array([JiraIssuesAndPushes::ERROR_WRONG_DEPLOY_DATE])
      end

      it 'with a blank secrets field' do
        mock_jira_find_issue_response('STORY-1234', secrets_modified: nil)
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.jira_issues_and_pushes.first.error_list).to \
          match_array([JiraIssuesAndPushes::ERROR_BLANK_SECRETS_MODIFIED])
      end

      it 'with a blank migration field' do
        mock_jira_find_issue_response('STORY-1234', long_running_migration: nil)
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.jira_issues_and_pushes.first.error_list).to \
          match_array([JiraIssuesAndPushes::ERROR_BLANK_LONG_RUNNING_MIGRATION])
      end
    end

    context 'without commits' do
      before do
        expect_any_instance_of(Git::Git).to receive(:clone_repository)
        expect_any_instance_of(Git::Git).to receive(:commit_diff_refs).and_return([])
        mock_jira_jql_response(['STORY-1234'])
      end

      it 'for this push, but had commits before' do
        other_push = create_test_push(sha: Git::TestHelpers.create_sha)
        commit = GitModels::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha)
        CommitsAndPushes.create_or_update!(commit, other_push)

        issue = create_test_jira_issue(key: 'STORY-1234')
        issue.commits << commit
        issue.save!
        JiraIssuesAndPushes.create_or_update!(issue, other_push)

        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        # we don't treat merged issues missing commits as a problem
        expect(push.jira_issues_and_pushes.first.merged).to be_truthy
        expect(push.jira_issues_and_pushes.first.error_list).to match_array([])
        expect(push.jira_issues_and_pushes.first.jira_issue.commits).not_to be_empty
      end

      it 'for this push, and never had commits before' do
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.jira_issues_and_pushes.first.error_list).to match_array([JiraIssuesAndPushes::ERROR_NO_COMMITS])
        expect(push.jira_issues_and_pushes.first.jira_issue.commits).to be_empty
      end
    end

    context 'when merged' do
      before do
        allow_any_instance_of(Git::Git).to receive(:clone_repository)
        allow_any_instance_of(Git::Git).to \
          receive(:commit_diff_refs).and_return([Git::TestHelpers.create_commit(message: 'STORY-1234 Description')])
        mock_jira_jql_response([])
      end

      it 'ignores all errors' do
        mock_jira_find_issue_response('STORY-1234', status: 'Wrong State', post_deploy_check_status: nil)

        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        jira_issue_and_push = push.jira_issues_and_pushes.first
        expect(jira_issue_and_push.error_list).to \
          match_array([JiraIssuesAndPushes::ERROR_WRONG_STATE, JiraIssuesAndPushes::ERROR_POST_DEPLOY_CHECK_STATUS])

        # mark the push as merged
        jira_issue_and_push.merged = true
        jira_issue_and_push.save

        # the error should be cleared
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        jira_issue_and_push = push.jira_issues_and_pushes.first
        expect(jira_issue_and_push.error_list).to \
          match_array([])
      end
    end
  end

  context 'detect commit issues' do
    before do
      mock_jira_jql_response([])
    end

    it 'without a matching JIRA issue' do
      stub_request(:get, /.*issue\/STORY-1234/).to_return(status: 404, body: 'Not Found')
      expect_any_instance_of(Git::Git).to receive(:clone_repository)
      expect_any_instance_of(Git::Git).to \
        receive(:commit_diff_refs).and_return([Git::TestHelpers.create_commit(message: 'STORY-1234 Description')])
      push = PushManager.process_push!(Push.create_from_github_data!(payload))
      expect(push.commits_and_pushes.first.error_list).to \
        match_array([CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
    end

    it 'without a JIRA issue number' do
      expect_any_instance_of(Git::Git).to receive(:clone_repository)
      expect_any_instance_of(Git::Git).to \
        receive(:commit_diff_refs).and_return(
          [Git::TestHelpers.create_commit(message: 'Description with issue number')]
        )
      push = PushManager.process_push!(Push.create_from_github_data!(payload))
      expect(push.commits_and_pushes.first.error_list).to \
        match_array([CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
    end
  end

  it 'ignore commits with matching messages, regardless of case' do
    mock_jira_jql_response([])
    GlobalSettings.jira.ignore_commits_with_messages = ['.*ignore1.*', '.*ignore2.*']
    commits = [Git::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha, message: '--Ignore1--'),
               Git::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha, message: '--Ignore2--'),
               Git::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha, message: 'KeepMe')]
    expect_any_instance_of(Git::Git).to receive(:clone_repository)
    expect_any_instance_of(Git::Git).to receive(:commit_diff_refs).and_return(commits)
    push = PushManager.process_push!(Push.create_from_github_data!(payload))
    expect(push.commits.count).to eq(1)
    expect(push.commits.first.sha).to eq(commits[2].sha)
  end

  it 'can handle commits with multiple issue numbers' do
    mock_jira_find_issue_response('STORY-1234')
    mock_jira_jql_response([])
    expect_any_instance_of(Git::Git).to receive(:clone_repository)
    expect_any_instance_of(Git::Git).to \
      receive(:commit_diff_refs).and_return(
        [Git::TestHelpers.create_commit(message: 'STORY-1234 description STORY-5678')]
      )
    push = PushManager.process_push!(Push.create_from_github_data!(payload))
    expect(push.jira_issues.count).to eq(1)
    expect(push.jira_issues.first.key).to eq('STORY-1234')
  end

  it 'can handle unclean issue numbers' do
    mock_jira_find_issue_response('STORY-1234')
    mock_jira_jql_response([])
    messages = [
      'STORY-1234',
      'STORY_1234',
      'STORY 1234',
      'story-1234',
      'Story-1234',
      '/STORY-1234',
      '/STORY-1234/',
      'STORY-1234/',
      ' STORY-1234',
      'STORY-1234 ',
      ' STORY-1234 ',
      '-STORY-1234',
      'STORY-1234-',
      '-STORY-1234-',
      '_STORY-1234',
      'STORY-1234_',
      '_STORY-1234_',
      '"STORY-1234',
      "'STORY-1234"
    ]
    commits = messages.collect do |message|
      Git::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha, message: message)
    end
    expect_any_instance_of(Git::Git).to receive(:clone_repository)
    expect_any_instance_of(Git::Git).to receive(:commit_diff_refs).and_return(commits)
    push = PushManager.process_push!(Push.create_from_github_data!(payload))
    expect(push.commits.count).to eq(19)
    push.commits.each do |commit|
      expect(commit.jira_issue.key).to eq('STORY-1234')
    end
  end

  context 'status' do
    before do
      allow_any_instance_of(Git::Git).to receive(:clone_repository)
      allow_any_instance_of(Git::Git).to \
        receive(:commit_diff_refs).and_return([Git::TestHelpers.create_commit(message: 'STORY-1234 Description')])
      mock_jira_jql_response([])
    end

    context 'has a failure status' do
      it 'when there is a jira error' do
        mock_jira_find_issue_response('STORY-1234', targeted_deploy_date: nil)
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.status).to eq('failure')
      end

      it 'when there is a commit error' do
        stub_request(:get, /\/rest\/api\/2\/issue\/STORY-1234/).to_return(status: 404, body: 'Not Found')
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.status).to eq('failure')
      end
    end

    context 'has a success status' do
      it 'when there are no errors' do
        mock_jira_find_issue_response('STORY-1234')
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.status).to eq('success')
      end

      it 'when there are no commits' do
        expect_any_instance_of(Git::Git).to receive(:clone_repository)
        expect_any_instance_of(Git::Git).to receive(:commit_diff_refs).and_return([])
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.commits.count).to eq(0)
        expect(push.status).to eq('success')
      end

      it 'when there is an accepted jira error' do
        mock_jira_find_issue_response('STORY-1234', targeted_deploy_date: nil)
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.status).to eq('failure')
        record = push.jira_issues_and_pushes.first
        record.ignore_errors = true
        record.save!
        push = PushManager.process_push!(push)
        expect(push.status).to eq('success')
      end

      it 'when there is an accepted commit error' do
        stub_request(:get, /\/rest\/api\/2\/issue\/STORY-1234/).to_return(status: 404, body: 'Not Found')
        push = PushManager.process_push!(Push.create_from_github_data!(payload))
        expect(push.status).to eq('failure')
        record = push.commits_and_pushes.first
        record.ignore_errors = true
        record.save!
        push = PushManager.process_push!(push)
        expect(push.status).to eq('success')
      end
    end
  end

  context 'purges stale' do
    before do
      @commits = [Git::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha, message: 'STORY-1234 Description'),
                  Git::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha, message: 'STORY-5678 Description')]
      allow_any_instance_of(Git::Git).to receive(:clone_repository).with(anything)
      mock_jira_jql_response([])
    end

    it 'commits' do
      stub_request(:get, /\/rest\/api\/2\/issue\/.*/).to_return(status: 404, body: 'Not Found')
      allow_any_instance_of(Git::Git).to receive(:commit_diff_refs).and_return([@commits[0], @commits[1]])
      push = PushManager.process_push!(Push.create_from_github_data!(payload))
      expect(push.commits.count).to eq(2)
      expect(push.commits[0].sha).to eq(@commits[0].sha)

      allow_any_instance_of(Git::Git).to receive(:commit_diff_refs).and_return([@commits[1]])
      push = PushManager.process_push!(push)
      expect(push.commits.count).to eq(1)
      expect(push.commits[0].sha).to eq(@commits[1].sha)
    end
  end

  it 'treats jira issues with old commits as merged and no commits as not merged' do
    @commits = [Git::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha, message: 'STORY-1234 Description'),
                Git::TestHelpers.create_commit(sha: Git::TestHelpers.create_sha, message: 'STORY-5678 Description')]
    allow_any_instance_of(Git::Git).to receive(:clone_repository).with(anything)
    mock_jira_jql_response(['STORY-9999'])

    # setup the push with two issues that have commits in the push, and one that has no commits
    mock_jira_find_issue_response('STORY-1234', post_deploy_check_status: 'Ready to Run')
    mock_jira_find_issue_response('STORY-5678')
    mock_jira_find_issue_response('STORY-9999')
    allow_any_instance_of(Git::Git).to receive(:commit_diff_refs).and_return([@commits[0], @commits[1]])
    push = PushManager.process_push!(Push.create_from_github_data!(payload))

    expect(push.jira_issues_and_pushes.merged.count).to eq(0)

    expect(push.jira_issues_and_pushes.not_merged.count).to eq(3)
    expect(push.jira_issues_and_pushes.not_merged[0].jira_issue.key).to eq('STORY-1234')
    expect(push.jira_issues_and_pushes.not_merged[0].jira_issue.post_deploy_check_status).to eq('Ready to Run')
    expect(push.jira_issues_and_pushes.not_merged[1].jira_issue.key).to eq('STORY-5678')
    expect(push.jira_issues_and_pushes.not_merged[2].jira_issue.key).to eq('STORY-9999')

    # update the push with one issue that has commits in the push, one issue that had commits, but don't any more, and one that never had any commits
    # we also change the post_deploy_check_status of the merged issue to confirm that we update merged issues
    mock_jira_find_issue_response('STORY-1234', post_deploy_check_status: 'Complete')
    mock_jira_find_issue_response('STORY-5678')
    mock_jira_find_issue_response('STORY-9999')
    allow_any_instance_of(Git::Git).to receive(:commit_diff_refs).and_return([@commits[1]])
    push = PushManager.process_push!(push)

    expect(push.jira_issues_and_pushes.merged.count).to eq(1)
    expect(push.jira_issues_and_pushes.merged[0].jira_issue.key).to eq('STORY-1234')
    expect(push.jira_issues_and_pushes.merged[0].jira_issue.post_deploy_check_status).to eq('Complete')

    expect(push.jira_issues_and_pushes.not_merged.count).to eq(2)
    expect(push.jira_issues_and_pushes.not_merged[0].jira_issue.key).to eq('STORY-5678')
    expect(push.jira_issues_and_pushes.not_merged[1].jira_issue.key).to eq('STORY-9999')
  end

  context 'uses appropriate ancestor branch' do
    before do
      mock_jira_jql_response([])
    end

    it 'for default' do
      expect_any_instance_of(Git::Git).to receive(:clone_repository).with('default_ancestor')
      GlobalSettings.jira.ancestor_branches['default'] = 'default_ancestor'
      expect_any_instance_of(Git::Git).to \
        receive(:commit_diff_refs).with(anything, 'default_ancestor', anything).and_return([])
      PushManager.process_push!(Push.create_from_github_data!(payload))
    end

    it 'for match' do
      expect_any_instance_of(Git::Git).to receive(:clone_repository).with('master')
      GlobalSettings.jira.ancestor_branches['test/branch_name'] = 'mybranch_ancestor'
      expect_any_instance_of(Git::Git).to \
        receive(:commit_diff_refs).with(anything, 'mybranch_ancestor', anything).and_return([])
      PushManager.process_push!(Push.create_from_github_data!(payload))
    end
  end
end
