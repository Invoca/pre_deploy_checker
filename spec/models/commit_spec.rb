# frozen_string_literal: true

require 'spec_helper'

describe 'Commit' do
  def payload
    Github::Api::PushHookPayload.new(load_json_fixture('github_push_payload'))
  end

  it 'can create be constructed from github data' do
    commit = Commit.create_from_github_data!(payload)
    expect(commit.sha).to eq('6d8cc7db8021d3dbf90a4ebd378d2ecb97c2bc25')
    expect(commit.message).not_to be_nil
    expect(commit.author.name).not_to be_nil
    expect(commit.author.email).not_to be_nil
    expect(commit.created_at).not_to be_nil
    expect(commit.updated_at).not_to be_nil
  end

  it 'can belong to a JIRA issue' do
    jira_issue = create_test_jira_issue
    commit = Commit.create_from_github_data!(payload)
    commit.jira_issue = jira_issue
    commit.save!
    expect(commit.jira_issue.id).to eq(jira_issue.id)
  end

  context '#message_contains_no_jira_tag?' do
    before do
      @commit = Commit.create_from_github_data!(payload)
    end

    ['no_jira', 'no-jira', 'NO-JIRA', 'NO_JIRA'].each do |message|
      it "returns true if message contains #{message}" do
        @commit.message = "#{message}: details"
        expect(@commit.message_contains_no_jira_tag?).to eq(true)
      end
    end

    it 'returns false if message does not contain a no_jira tag' do
      @commit.message = 'not tagged with the no and jira tag'
      expect(@commit.message_contains_no_jira_tag?).to eq(false)
    end
  end

  context 'pushes' do
    before do
      @commit = create_commit
      @push = create_test_push
      # remove head commit so we don't confuse it with the commit we are testing
      @push.commits_and_pushes.destroy_all
      @push.head_commit.destroy
      expect(@commit.pushes.count).to eq(0)
    end

    it 'can belong to one' do
      CommitsAndPushes.create_or_update!(@commit, @push)
      @commit.reload
      @push.reload
      expect(@commit.pushes.count).to eq(1)
      expect(@push.commits.count).to eq(1)
    end
  end
end
