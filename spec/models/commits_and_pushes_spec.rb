# frozen_string_literal: true

require 'spec_helper'

describe 'CommitsAndPushes' do
  before do
    @commit = create_commit
    @push = create_test_push
    # remove head commit so we don't confuse it with the commit we are testing
    @push.commits_and_pushes.destroy_all
    @push.head_commit.destroy
  end

  context 'construction' do
    it 'without errors' do
      record = CommitsAndPushes.create_or_update!(@commit, @push)
      @commit.reload
      @push.reload
      expect(@commit.pushes.count).to eq(1)
      expect(@push.commits.count).to eq(1)
      expect(record.error_list).to match_array([])
      expect(record.ignore_errors).to be_falsey
    end

    it 'with errors' do
      record = CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
      @commit.reload
      @push.reload
      expect(@commit.pushes.count).to eq(1)
      expect(@push.commits.count).to eq(1)
      expect(record.error_list).to match_array([CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
      expect(record.ignore_errors).to be_falsey
    end

    it 'duplicate errors are consolidated' do
      record = CommitsAndPushes.create_or_update!(
        @commit,
        @push,
        [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER, CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER]
      )
      expect(record.error_list).to match_array([CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
    end

    it 'does not create duplicate database records' do
      CommitsAndPushes.create_or_update!(@commit, @push)
      expect(CommitsAndPushes.all.count).to eq(1)

      CommitsAndPushes.create_or_update!(@commit, @push)
      expect(CommitsAndPushes.all.count).to eq(1)
    end

    context 'with ignored errors' do
      before do
        @record = CommitsAndPushes.create_or_update!(
          @commit,
          @push,
          [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER, CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND]
        )
        @record.ignore_errors = true
        @record.save!
      end

      it 'changes to errors clears the ignore flag' do
        CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
        @record.reload
        expect(@record.error_list).to match_array([CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
        expect(@record.ignore_errors).to be_falsey
      end

      it 'existing errors do not clear the ignore flag, even if the error order is different' do
        CommitsAndPushes.create_or_update!(
          @commit,
          @push,
          [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND, CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER]
        )
        @record.reload
        expect(@record.error_list).to match_array([CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER,
                                                   CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
        expect(@record.ignore_errors).to be_truthy
      end

      it 'detects the ignored errors' do
        expect(@record.errors?).to be_truthy
        expect(@record.ignored_errors?).to be_truthy
        expect(@record.unignored_errors?).to be_falsey
      end

      it 'copies the ignore_errors flag from its predecessor' do
        new_push = create_test_push(sha: Git::TestHelpers.create_sha)
        record = CommitsAndPushes.create_or_update!(
          @commit,
          new_push,
          [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER, CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND]
        )
        expect(record.ignore_errors).to be_truthy
      end
    end
  end

  context 'with_unignored_errors scope' do
    it 'can find pushes with errors' do
      CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
      @commit.reload
      expect(@commit.commits_and_pushes.with_unignored_errors.count).to eq(1)
      expect(@push.commits_and_pushes.with_unignored_errors.error_counts).to \
        eq(CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND => 1)
    end

    it 'excludes pushes with ignored errors' do
      record = CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
      record.ignore_errors = true
      record.save!
      @commit.reload
      expect(@commit.commits_and_pushes.with_unignored_errors.count).to eq(0)
      expect(@push.commits_and_pushes.with_unignored_errors.error_counts).to eq({})
    end

    it 'excludes pushes without errors' do
      CommitsAndPushes.create_or_update!(@commit, @push, [])
      @commit.reload
      expect(@commit.commits_and_pushes.with_unignored_errors.count).to eq(0)
      expect(@push.commits_and_pushes.with_unignored_errors.error_counts).to eq({})
    end
  end

  context 'destroy_if_commit_not_in_list' do
    context 'with commits' do
      before do
        CommitsAndPushes.create_or_update!(@commit, @push)
        @second_commit = create_commit(sha: Git::TestHelpers.create_sha)
        CommitsAndPushes.create_or_update!(@second_commit, @push)
        @third_commit = create_commit(sha: Git::TestHelpers.create_sha)
        CommitsAndPushes.create_or_update!(@third_commit, @push)
        expect(@push.commits.count).to eq(3)
      end

      it 'only destroy commits not in the list' do
        CommitsAndPushes.destroy_if_commit_not_in_list(@push, [@second_commit])
        expect(@push.commits.count).to eq(1)
        expect(@push.commits.first).to eq(@second_commit)
      end

      it 'destroys all commits if the list is empty' do
        CommitsAndPushes.destroy_if_commit_not_in_list(@push, [])
        expect(@push.commits).to be_empty
      end
    end

    context 'without commits' do
      it 'does not fail if there are no commits to destroy' do
        expect(@push.commits).to be_empty
        CommitsAndPushes.destroy_if_commit_not_in_list(@push, [@commit])
      end
    end
  end

  context '#with_no_jira_tag' do
    before do
      second_commit   = create_commit(sha: '1234567890123456789012345678901234567891')
      @normal_record  = CommitsAndPushes.create_or_update!(@commit, @push)
      @no_jira_record = CommitsAndPushes.create_or_update!(second_commit, @push)
      @no_jira_record.no_jira = true
      @no_jira_record.save!
    end

    it 'returns only commits and pushes that have no_jira set to false' do
      with_no_jira_scope = CommitsAndPushes.with_no_jira_tag
      expect(with_no_jira_scope.count).to eq(1)
      expect(with_no_jira_scope.first).to eq(@no_jira_record)
    end
  end
end
