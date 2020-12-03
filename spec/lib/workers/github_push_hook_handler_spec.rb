# frozen_string_literal: true

require 'spec_helper'

describe 'GithubPushHookHandler' do
  let(:payload) { load_json_fixture('github_push_payload') }

  before(:each) do
    allow(Push).to receive(:create_from_github_data!).and_return([double])
  end

  it 'can create be constructed' do
    handler = GithubPushHookHandler.new
    expect(handler).not_to be_nil
  end

  it 'submits pushes for processing' do
    expect_any_instance_of(PushChangeHandler).to receive(:submit_push_for_processing!)

    GithubPushHookHandler.new.queue!(payload)

    # a job should be queued
    expect(Delayed::Job.count).to eq(1)

    # process the job
    expect(Delayed::Worker.new.work_off(1)).to eq([1, 0])
  end

  it 'does not process pushes for branches in the ignore list' do
    expect_any_instance_of(PushChangeHandler).not_to receive(:submit_push_for_processing!)
    GlobalSettings.jira.ignore_branches << '.*branch_name'

    GithubPushHookHandler.new.queue!(payload)

    # a job should be queued
    expect(Delayed::Job.count).to eq(1)

    # process the job
    expect(Delayed::Worker.new.work_off(1)).to eq([1, 0])

    # it should not have queued another job
    expect(Delayed::Job.count).to eq(0)
  end

  it 'does not process pushes for branches not in the only list' do
    expect_any_instance_of(PushChangeHandler).not_to receive(:submit_push_for_processing!)
    GlobalSettings.jira.only_branches << 'not_a_match'

    GithubPushHookHandler.new.queue!(payload)

    # a job should be queued
    expect(Delayed::Job.count).to eq(1)

    # process the job
    expect(Delayed::Worker.new.work_off(1)).to eq([1, 0])

    # it should not have queued another job
    expect(Delayed::Job.count).to eq(0)
  end
end
