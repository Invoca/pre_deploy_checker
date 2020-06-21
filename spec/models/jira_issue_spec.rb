require 'spec_helper'

describe 'JiraIssue' do
  def jira_issue
    @jira_issue ||= JIRA::Resource::IssueFactory.new(jira_client).build(load_json_fixture('jira_issue_response'))
  end

  def jira_sub_task
    @jira_sub_task ||= JIRA::Resource::IssueFactory.new(jira_client).build(load_json_fixture('jira_sub_task_response'))
  end

  def assert_issue_properly_constructed(issue)
    expect(issue.key).to eq('STORY-4380')
    expect(issue.summary).to eq('This is the issue summary')
    expect(issue.issue_type).to eq('Story')
    expect(issue.status).to eq('Code Review')
    expect(issue.post_deploy_check_status).to eq('Ready to Run')
    expect(issue.deploy_type).to eq('Web, PNAPI')
    expect(issue.long_running_migration).to eq('No')

    expect(issue.parent_issue).to be_nil
    expect(issue.pushes).to eq([])
    expect(issue.assignee.name).to eq('Author Name')
    expect(issue.assignee.email).to eq('aname@email.com')
  end

  context 'construction' do
    it 'can be constructed and saved from jira data' do
      issue = JiraIssue.create_from_jira_data!(jira_client, jira_issue)
      assert_issue_properly_constructed(issue)
      expect(issue.new_record?).to be_falsey
      expect(issue.created_at).not_to be_nil
      expect(issue.updated_at).not_to be_nil
    end

    it 'can be constructed from jira data' do
      issue = JiraIssue.create_from_jira_data(jira_client, jira_issue)
      assert_issue_properly_constructed(issue)
      expect(issue.new_record?).to be_truthy
      expect(issue.created_at).to be_nil
      expect(issue.updated_at).to be_nil
    end
  end

  it 'does not create duplicate database records' do
    JiraIssue.create_from_jira_data!(jira_client, jira_issue)
    expect(JiraIssue.all.count).to eq(1)

    JiraIssue.create_from_jira_data!(jira_client, jira_issue)
    expect(JiraIssue.all.count).to eq(1)
  end

  it 'rejects keys that are invalid' do
    expect { create_test_jira_issue(key: 'invalidkey') }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  context 'assignee' do
    it 'can be nil' do
      issue_json = load_json_fixture('jira_issue_response')
      issue_json['fields']['assignee'] = nil
      issue = JiraIssue.create_from_jira_data!(jira_client, JIRA::Resource::IssueFactory.new(jira_client).build(issue_json))
      expect(issue.assignee).to be_nil
    end

    it 'can be changed' do
      orginal_issue = JiraIssue.create_from_jira_data!(jira_client, jira_issue)

      jira_issue.assignee.attrs['displayName'] = 'Other User'

      updated_issue = JiraIssue.create_from_jira_data!(jira_client, jira_issue)

      expect(User.count).to eq(2)
      expect(orginal_issue.assignee.id).not_to eq(updated_issue.assignee.id)
      expect(updated_issue.assignee.email).to eq('ouser@email.com')
    end
  end

  context 'commits' do
    it 'can own some' do
      issue = JiraIssue.create_from_jira_data!(jira_client, jira_issue)
      expect(issue.commits.count).to eq(0)
      GitModels::TestHelpers.create_commits.each do |commit|
        commit.jira_issue = issue
        commit.save!
      end
      issue.reload
      expect(issue.commits.count).to eq(2)
    end

    it 'can find the latest' do
      issue = JiraIssue.create_from_jira_data!(jira_client, jira_issue)
      expect(issue.commits.count).to eq(0)
      GitModels::TestHelpers.create_commits.each do |commit|
        # TODO: when commit dates are added, improve this test
        commit.jira_issue = issue
        commit.save!
      end
      issue.reload
      expect(issue.latest_commit.id).to eq(issue.commits.first.id)
    end
  end

  context 'pushes' do
    before do
      @issue = JiraIssue.create_from_jira_data!(jira_client, jira_issue)
      @push = create_test_push
      expect(@issue.pushes.count).to eq(0)
    end

    it 'can belong to one' do
      JiraIssuesAndPushes.create_or_update!(@issue, @push)
      @issue.reload
      @push.reload
      expect(@issue.pushes.count).to eq(1)
      expect(@push.jira_issues.count).to eq(1)
    end
  end

  context 'subtask parent' do
    it 'gets created if it does not exist' do
      child_issue = JiraIssue.create_from_jira_data!(jira_client, jira_sub_task)
      expect(child_issue.key).to eq('STORY-4240')
      expect(child_issue.parent_issue.key).to eq('STORY-4380')
      expect(child_issue.sub_task?).to be_truthy
      expect(JiraIssue.count).to eq(2)
    end

    it 'uses parent if it exists' do
      # create the parent issue for the child to be related to
      parent_issue = JiraIssue.create_from_jira_data!(jira_client, jira_issue)
      child_issue = JiraIssue.create_from_jira_data!(jira_client, jira_sub_task)
      expect(child_issue.key).to eq('STORY-4240')
      expect(child_issue.parent_issue.key).to eq('STORY-4380')
      expect(child_issue.parent_issue).to eq(parent_issue)
      expect(JiraIssue.count).to eq(2)
    end

    it 'can be changed' do
      orginal_issue = JiraIssue.create_from_jira_data!(jira_client, jira_sub_task)

      jira_sub_task.parent['key'] = 'STORY-9999'

      updated_issue = JiraIssue.create_from_jira_data!(jira_client, jira_sub_task)

      expect(JiraIssue.count).to eq(3)
      expect(orginal_issue.parent_issue.id).not_to eq(updated_issue.parent_issue.id)
      expect(updated_issue.parent_issue.key).to eq('STORY-9999')
    end
  end

  context 'sorting' do
    context 'with parents' do
      before do
        # intentionally creating the issues out of order to verify we are not sorting by id
        @issue_2 = create_test_jira_issue(key: 'WEB-1234')
        @issue_2_child_2 = create_test_jira_issue(key: 'WEB-9000', parent_key: 'WEB-1234')
        @issue_1 = create_test_jira_issue(key: 'WEB-1000')
        @issue_3 = create_test_jira_issue(key: 'WEB-5678')
        @issue_3_child_1 = create_test_jira_issue(key: 'WEB-4000', parent_key: 'WEB-5678')
        @issue_2_child_1 = create_test_jira_issue(key: 'WEB-3000', parent_key: 'WEB-1234')
      end

      it 'comparison' do
        expect(@issue_2 <=> @issue_2_child_2).to eq(0)
        expect(@issue_2 <=> @issue_2_child_1).to eq(0)
        expect(@issue_2_child_1 <=> @issue_2_child_2).to eq(-1)
        expect(@issue_3 <=> @issue_2_child_2).to eq(1)
        expect(@issue_1 <=> @issue_2_child_2).to eq(-1)
        expect(@issue_2_child_2 <=> @issue_3_child_1).to eq(-1)
      end

      it 'can be sorted' do
        expected_issues = [
          @issue_1,
          @issue_2,
          @issue_2_child_1,
          @issue_2_child_2,
          @issue_3,
          @issue_3_child_1
        ]
        expect(JiraIssue.all.sort).to match_array(expected_issues)
      end
    end

    context 'with no parents' do
      before do
        # intentionally creating the issues out of order to verify we are not sorting by id
        @issue_2 = create_test_jira_issue(key: 'WEB-1234')
        @issue_1 = create_test_jira_issue(key: 'WEB-1000')
        @issue_3 = create_test_jira_issue(key: 'WEB-5678')
        @issue_4 = create_test_jira_issue(key: 'WEB-200')
      end

      it 'comparison' do
        expect(@issue_2 <=> @issue_2).to eq(0) # rubocop:disable Lint/UselessComparison
        expect(@issue_1 <=> @issue_2).to eq(-1)
        expect(@issue_3 <=> @issue_2).to eq(1)
        expect(@issue_4 <=> @issue_1).to eq(-1)
        expect(@issue_4 <=> @issue_2).to eq(-1)
        expect(@issue_4 <=> @issue_3).to eq(-1)
      end

      it 'can be sorted' do
        expected_issues = [
          @issue_4,
          @issue_1,
          @issue_2,
          @issue_3
        ]
        expect(JiraIssue.all.sort).to match_array(expected_issues)
      end
    end
  end
end
