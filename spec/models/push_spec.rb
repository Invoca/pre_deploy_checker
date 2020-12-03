# frozen_string_literal: true

require 'spec_helper'

describe 'Push' do
  before(:all) do
    Service.destroy_all
    Service.create!([
                      { name: 'web1', ref: 'production' },
                      { name: 'rs1',  ref: 'a_whole_new_ref' }
                    ])
  end

  let(:payload) { Github::Api::PushHookPayload.new(load_json_fixture('github_push_payload')) }

  it 'can create be constructed from github data' do
    service_names = ['web1', 'rs1']
    pushes = Push.create_from_github_data!(payload)
    pushes.each_with_index do |push, i|
      expect(push.status).to eq(Github::Api::Status::STATE_PENDING.to_s)
      expect(push.head_commit).not_to be_nil
      expect(push.branch).not_to be_nil
      expect(push.commits.count).to eq(1)
      expect(push.jira_issues.count).to eq(0)
      expect(push.created_at).not_to be_nil
      expect(push.updated_at).not_to be_nil
      expect(push.email_sent).to eq(false)
      expect(push.service_name).to eq(service_names[i])
    end
  end

  it 'creates one push for each Ancestor Ref' do
    Push.create_from_github_data!(payload)
    expect(Push.all.count).to eq(Service.all.count)
  end

  it 'does not create duplicate database records' do
    Push.create_from_github_data!(payload)
    expect(Push.all.count).to eq(Service.all.count)

    expect do
      Push.create_from_github_data!(payload)
    end.to_not change { Push.all.count }
  end

  context 'commits' do
    before do
      @push = Push.create_from_github_data!(payload).first
      expect(@push.commits.count).to eq(1)
    end

    it 'can own some' do
      create_commits.each do |commit|
        CommitsAndPushes.create_or_update!(commit, @push)
      end
      @push.reload
      expect(@push.commits.count).to eq(3)
      expect(@push.commits_with_errors?).to be_falsey
      expect(@push.commits_with_errors.count).to eq(0)
      expect(@push.errors?).to be_falsey
      expect(@push.commits_with_unignored_errors?).to be_falsey
    end

    it 'can detect ones with errors' do
      expect(@push.commits_with_errors?).to be_falsey
      expect(@push.commits_with_errors.count).to eq(0)
      expect(@push.errors?).to be_falsey
      expect(@push.commits_with_unignored_errors?).to be_falsey
      create_commits.each do |commit|
        CommitsAndPushes.create_or_update!(commit, @push, [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
      end
      expect(@push.commits_with_errors?).to be_truthy
      expect(@push.commits_with_errors.count).to eq(2)
      expect(@push.errors?).to be_truthy
      expect(@push.commits_with_unignored_errors?).to be_truthy
    end

    context 'no_jira commits_and_pushes' do
      before do
        @no_jira_record = @push.commits_and_pushes.first
        @no_jira_record.no_jira = true
        @no_jira_record.save!
      end

      it 'can detect records with no_jira set to true' do
        no_jira_commits = @push.no_jira_commits
        expect(no_jira_commits.count).to eq(1)
        expect(no_jira_commits.first).to eq(@no_jira_record)
      end

      it 'returns nothing if no records have no_jira set to true' do
        @no_jira_record.destroy!
        expect(@push.no_jira_commits.empty?).to be_truthy
      end

      it 'returns true if there are commits and pushes with no_jira set to true' do
        expect(@push.no_jira_commits?).to be_truthy
      end

      it 'returns false if there are no commits and pushes with no_jira set to true' do
        @no_jira_record.destroy!
        expect(@push.reload.no_jira_commits?).to be_falsey
      end
    end

    it 'can compute status' do
      CommitsAndPushes.create_or_update!(create_commit(sha: Git::TestHelpers.create_sha), @push)
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_SUCCESS)
      error_record = CommitsAndPushes.create_or_update!(
        create_commit(sha: Git::TestHelpers.create_sha),
        @push,
        [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND]
      )
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_FAILED)
      error_record.ignore_errors = true
      error_record.save!
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_SUCCESS)
    end
  end

  context 'jira_issues' do
    before do
      @push = Push.create_from_github_data!(payload).first
    end

    it 'can own some' do
      expect(@push.jira_issues?).to be_falsey
      JiraIssuesAndPushes.create_or_update!(create_test_jira_issue, @push)
      @push.reload
      expect(@push.jira_issues?).to be_truthy
      expect(@push.jira_issues.count).to eq(1)
      expect(@push.jira_issues_with_errors?).to be_falsey
      expect(@push.jira_issues_with_errors.count).to eq(0)
      expect(@push.errors?).to be_falsey
      expect(@push.jira_issues_with_unignored_errors?).to be_falsey
      expect(@push.jira_issue_keys).to match_array(['STORY-4380'])
    end

    it 'can be found by jira issue key' do
      jira_issue = create_test_jira_issue
      JiraIssuesAndPushes.create_or_update!(jira_issue, @push)
      expect(Push.with_jira_issue(jira_issue.key).count).to eq(1)
      expect(Push.with_jira_issue('STORY-0000')).to be_empty
    end

    it 'can be found by service' do
      expect(Push.for_service(@push.service_name).count).to eq(1)
      expect(Push.for_service('bogus_ref')).to be_empty
    end

    it 'can be found by head commit and service combination' do
      head_commit  = @push.head_commit.sha
      service_name = @push.service_name

      expect(Push.for_commit_and_service(head_commit, service_name).count).to eq(1)
      expect(Push.for_commit_and_service('bogus_commit', 'bogus_ref')).to be_empty
    end

    it 'can detect ones with errors' do
      JiraIssuesAndPushes.create_or_update!(create_test_jira_issue, @push)
      expect(@push.jira_issues_with_errors?).to be_falsey
      expect(@push.jira_issues_with_errors.count).to eq(0)
      expect(@push.errors?).to be_falsey
      expect(@push.jira_issues_with_unignored_errors?).to be_falsey

      JiraIssuesAndPushes.create_or_update!(
        create_test_jira_issue(key: 'WEB-1234'),
        @push,
        [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND]
      )
      JiraIssuesAndPushes.create_or_update!(
        create_test_jira_issue(key: 'WEB-5468'),
        @push,
        [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND]
      )
      expect(@push.jira_issues_with_errors?).to be_truthy
      expect(@push.jira_issues_with_errors.count).to eq(2)
      expect(@push.errors?).to be_truthy
      expect(@push.jira_issues_with_unignored_errors?).to be_truthy
    end

    it 'can compute status' do
      JiraIssuesAndPushes.create_or_update!(create_test_jira_issue, @push)
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_SUCCESS)
      error_record = JiraIssuesAndPushes.create_or_update!(
        create_test_jira_issue(key: 'WEB-1234'),
        @push,
        [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND]
      )
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_FAILED)
      error_record.ignore_errors = true
      error_record.save!
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_SUCCESS)
    end
  end
end
