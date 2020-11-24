# frozen_string_literal: true

require 'spec_helper'

describe 'JiraHookHandler' do
  def jira_payload
    @jira_payload ||= load_json_fixture('jira_hook_payload')
  end

  def github_payload
    @github_payload ||= Github::Api::PushHookPayload.new(load_json_fixture('github_push_payload'))
  end

  it 'can create be constructed' do
    handler = JiraHookHandler.new
    expect(handler).not_to be_nil
  end

  it 'is handled by a delayed job' do
    push = Push.create_from_github_data!(github_payload)
    JiraIssuesAndPushes.create_or_update!(create_test_jira_issue(key: 'STORY-4380'), push)

    expect_any_instance_of(PushChangeHandler).to receive(:submit_push_for_processing!)

    JiraHookHandler.new.queue!(jira_payload)

    # a job should be queued
    expect(Delayed::Job.count).to eq(1)

    # process the job
    expect(Delayed::Worker.new.work_off(1)).to eq([1, 0])
  end

  it 'submits pushes for processing', disable_delayed_job: true do
    push = Push.create_from_github_data!(github_payload)
    JiraIssuesAndPushes.create_or_update!(create_test_jira_issue(key: 'STORY-4380'), push)

    expect_any_instance_of(PushChangeHandler).to receive(:submit_push_for_processing!)

    JiraHookHandler.new.queue!(jira_payload)
  end

  it 'does not process hooks for issues that have no pushes associated with them', disable_delayed_job: true do
    expect_any_instance_of(PushChangeHandler).not_to receive(:submit_push_for_processing!)
    GlobalSettings.jira.ignore_branches << '.*branch_name'

    JiraHookHandler.new.queue!(jira_payload)
  end

  it 'does not process hooks for issues that have no material changes', disable_delayed_job: true do
    push = Push.create_from_github_data!(github_payload)
    jira_issue = JiraIssue.create_from_jira_data!(JIRA::Resource::IssueFactory.new(nil).build(jira_payload['issue']))
    JiraIssuesAndPushes.create_or_update!(jira_issue, push)
    expect_any_instance_of(PushChangeHandler).not_to receive(:submit_push_for_processing!)

    JiraHookHandler.new.queue!(jira_payload)
  end

  it 'process hooks for issues that only have minor differences', disable_delayed_job: true do
    push = Push.create_from_github_data!(github_payload)
    jira_issue = JiraIssue.create_from_jira_data(JIRA::Resource::IssueFactory.new(nil).build(jira_payload['issue']))
    jira_issue.summary = 'This is a different summary'
    jira_issue.save!
    JiraIssuesAndPushes.create_or_update!(jira_issue, push)
    expect_any_instance_of(PushChangeHandler).to receive(:submit_push_for_processing!)

    JiraHookHandler.new.queue!(jira_payload)
  end
end
