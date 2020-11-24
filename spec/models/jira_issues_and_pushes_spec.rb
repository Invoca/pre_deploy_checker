# frozen_string_literal: true

require 'spec_helper'

describe 'JiraIssuesAndPushes' do
  def jira_issue
    @jira_issue ||= JIRA::Resource::IssueFactory.new(nil).build(load_json_fixture('jira_issue_response'))
  end

  before do
    @issue = JiraIssue.create_from_jira_data!(jira_issue)
    @push = create_test_push
  end

  context 'construction' do
    it 'without errors' do
      record = JiraIssuesAndPushes.create_or_update!(@issue, @push)
      @issue.reload
      @push.reload
      expect(@issue.pushes.count).to eq(1)
      expect(@push.jira_issues.count).to eq(1)
      expect(record.error_list).to match_array([])
      expect(record.ignore_errors).to be_falsey
    end

    it 'with errors' do
      record = JiraIssuesAndPushes.create_or_update!(@issue, @push, [JiraIssuesAndPushes::ERROR_WRONG_STATE])
      @issue.reload
      @push.reload
      expect(@issue.pushes.count).to eq(1)
      expect(@push.jira_issues.count).to eq(1)
      expect(record.error_list).to match_array([JiraIssuesAndPushes::ERROR_WRONG_STATE])
      expect(record.ignore_errors).to be_falsey
    end

    it 'duplicate errors are consolidated' do
      record = JiraIssuesAndPushes.create_or_update!(
        @issue,
        @push,
        [JiraIssuesAndPushes::ERROR_WRONG_STATE, JiraIssuesAndPushes::ERROR_WRONG_STATE]
      )
      expect(record.error_list).to match_array([JiraIssuesAndPushes::ERROR_WRONG_STATE])
    end

    it 'does not create duplicate database records' do
      JiraIssuesAndPushes.create_or_update!(@issue, @push)
      expect(JiraIssuesAndPushes.all.count).to eq(1)

      JiraIssuesAndPushes.create_or_update!(@issue, @push)
      expect(JiraIssuesAndPushes.all.count).to eq(1)
    end

    context 'with ignored errors' do
      before do
        @record = JiraIssuesAndPushes.create_or_update!(
          @issue,
          @push,
          [JiraIssuesAndPushes::ERROR_WRONG_STATE, JiraIssuesAndPushes::ERROR_NO_COMMITS]
        )
        @record.ignore_errors = true
        @record.save!
      end

      it 'changes to errors clears the ignore flag' do
        JiraIssuesAndPushes.create_or_update!(@issue, @push, [JiraIssuesAndPushes::ERROR_WRONG_STATE])
        @record.reload
        expect(@record.error_list).to match_array([JiraIssuesAndPushes::ERROR_WRONG_STATE])
        expect(@record.ignore_errors).to be_falsey
      end

      it 'existing errors do not clear the ignore flag, even if the error order is different' do
        JiraIssuesAndPushes.create_or_update!(
          @issue,
          @push,
          [JiraIssuesAndPushes::ERROR_NO_COMMITS, JiraIssuesAndPushes::ERROR_WRONG_STATE]
        )
        @record.reload
        expect(@record.error_list).to match_array(
          [JiraIssuesAndPushes::ERROR_WRONG_STATE, JiraIssuesAndPushes::ERROR_NO_COMMITS]
        )
        expect(@record.ignore_errors).to be_truthy
      end

      it 'detects the ignored errors' do
        expect(@record.errors?).to be_truthy
        expect(@record.ignored_errors?).to be_truthy
        expect(@record.unignored_errors?).to be_falsey
      end

      it 'copies the ignore_errors flag from its predecessor' do
        new_push = create_test_push(sha: Git::TestHelpers.create_sha)
        record = JiraIssuesAndPushes.create_or_update!(
          @issue,
          new_push,
          [JiraIssuesAndPushes::ERROR_NO_COMMITS, JiraIssuesAndPushes::ERROR_WRONG_STATE]
        )
        expect(record.ignore_errors).to be_truthy
      end
    end
  end

  context 'with commits' do
    it 'that are related' do
      commit = create_commit(sha: Git::TestHelpers.create_sha)
      CommitsAndPushes.create_or_update!(commit, @push)
      @issue.commits << commit
      @issue.save!

      issue_or_push = JiraIssuesAndPushes.create_or_update!(@issue, @push)
      expect(issue_or_push.commits).not_to be_empty
    end

    it 'that are not related' do
      other_push = create_test_push(sha: Git::TestHelpers.create_sha)
      commit = create_commit(sha: Git::TestHelpers.create_sha)
      CommitsAndPushes.create_or_update!(commit, other_push)
      JiraIssuesAndPushes.create_or_update!(@issue, other_push)
      @issue.commits << commit
      @issue.save!

      issue_or_push = JiraIssuesAndPushes.create_or_update!(@issue, @push)
      expect(issue_or_push.commits).to be_empty
    end
  end

  context 'with_unignored_errors scope' do
    it 'can find pushes with errors' do
      JiraIssuesAndPushes.create_or_update!(@issue, @push, [JiraIssuesAndPushes::ERROR_WRONG_STATE])
      @issue.reload
      expect(@issue.jira_issues_and_pushes.with_unignored_errors.count).to eq(1)
      expect(JiraIssuesAndPushes.get_error_counts_for_push(@push)).to \
        eq(JiraIssuesAndPushes::ERROR_WRONG_STATE => 1)
    end

    it 'excludes pushes with ignored errors' do
      record = JiraIssuesAndPushes.create_or_update!(@issue, @push, [JiraIssuesAndPushes::ERROR_WRONG_STATE])
      record.ignore_errors = true
      record.save!
      @issue.reload
      expect(@issue.jira_issues_and_pushes.with_unignored_errors.count).to eq(0)
      expect(JiraIssuesAndPushes.get_error_counts_for_push(@push)).to eq({})
    end

    it 'excludes pushes without errors' do
      JiraIssuesAndPushes.create_or_update!(@issue, @push, [])
      @issue.reload
      expect(@issue.jira_issues_and_pushes.with_unignored_errors.count).to eq(0)
      expect(JiraIssuesAndPushes.get_error_counts_for_push(@push)).to eq({})
    end
  end

  context 'mark_all_as_merged' do
    context 'with jira_issues' do
      before do
        JiraIssuesAndPushes.create_or_update!(@issue, @push)
        @second_issue = create_test_jira_issue(key: 'WEB-1234')
        JiraIssuesAndPushes.create_or_update!(@second_issue, @push)
        @third_issue = create_test_jira_issue(key: 'WEB-5678')
        JiraIssuesAndPushes.create_or_update!(@third_issue, @push)
        expect(@push.jira_issues_and_pushes.count).to eq(3)
        expect(@push.jira_issues_and_pushes.merged).to be_empty
      end

      it 'marks all issues as merged' do
        JiraIssuesAndPushes.mark_all_as_merged(@push)
        expect(@push.jira_issues_and_pushes.merged.count).to eq(3)
        expect(@push.jira_issues_and_pushes.not_merged).to be_empty
      end
    end

    context 'without jira_issues' do
      it 'does not fail if there are no issues to mark as merged' do
        expect(@push.jira_issues_and_pushes).to be_empty
        JiraIssuesAndPushes.mark_all_as_merged(@push)
      end
    end
  end

  context 'destroy_if_jira_issue_not_in_list' do
    context 'with jira_issues' do
      before do
        JiraIssuesAndPushes.create_or_update!(@issue, @push)
        @second_issue = create_test_jira_issue(key: 'WEB-1234')
        JiraIssuesAndPushes.create_or_update!(@second_issue, @push)
        @third_issue = create_test_jira_issue(key: 'WEB-5678')
        JiraIssuesAndPushes.create_or_update!(@third_issue, @push)
        expect(@push.jira_issues_and_pushes.count).to eq(3)
      end

      it 'only destroys issues not in the list' do
        JiraIssuesAndPushes.destroy_if_jira_issue_not_in_list(@push, [@second_issue])
        expect(@push.jira_issues_and_pushes.count).to eq(1)
        expect(@push.jira_issues_and_pushes.first.jira_issue).to eq(@second_issue)
      end

      it 'destroys all issues if the list is empty' do
        JiraIssuesAndPushes.destroy_if_jira_issue_not_in_list(@push, [])
        expect(@push.jira_issues_and_pushes).to be_empty
      end
    end

    context 'without jira_issues' do
      it 'does not fail if there are no issues to destroy' do
        expect(@push.jira_issues_and_pushes).to be_empty
        JiraIssuesAndPushes.destroy_if_jira_issue_not_in_list(@push, [@issue])
      end
    end
  end

  context 'sorting' do
    before do
      # intentionally creating the issues out of order to verify we are not sorting by id
      @push_1_issue_2 = JiraIssuesAndPushes.create_or_update!(create_test_jira_issue(key: 'WEB-1234'), @push)
      @push_1_issue_1 = JiraIssuesAndPushes.create_or_update!(create_test_jira_issue(key: 'WEB-1000'), @push)
      @push_1_issue_3 = JiraIssuesAndPushes.create_or_update!(create_test_jira_issue(key: 'WEB-5678'), @push)

      second_push = create_test_push(sha: '8888888888')
      @push_2_issue_1 = JiraIssuesAndPushes.create_or_update!(create_test_jira_issue(key: 'WEB-9012'), second_push)

      third_push = create_test_push(sha: '9999999999')
      @push_3_issue_1 = JiraIssuesAndPushes.create_or_update!(create_test_jira_issue(key: 'WEB-0000'), third_push)
    end

    it 'by push first' do
      expect(@push_2_issue_1 <=> @push_2_issue_1).to eq(0) # rubocop:disable Lint/UselessComparison
      expect(@push_1_issue_1 <=> @push_2_issue_1).to eq(-1)
      expect(@push_1_issue_2 <=> @push_2_issue_1).to eq(-1)
      expect(@push_1_issue_3 <=> @push_2_issue_1).to eq(-1)
      expect(@push_3_issue_1 <=> @push_2_issue_1).to eq(1)
    end

    it 'by jira issue second' do
      expect(@push_1_issue_2 <=> @push_1_issue_2).to eq(0) # rubocop:disable Lint/UselessComparison
      expect(@push_1_issue_1 <=> @push_1_issue_2).to eq(-1)
      expect(@push_1_issue_3 <=> @push_1_issue_2).to eq(1)
    end

    it 'can be sorted' do
      expected_issues_and_pushes = [
        @push_1_issue_1,
        @push_1_issue_2,
        @push_1_issue_3,
        @push_2_issue_1,
        @push_3_issue_1
      ]
      expect(JiraIssuesAndPushes.all.sort).to match_array(expected_issues_and_pushes)
    end
  end
end
