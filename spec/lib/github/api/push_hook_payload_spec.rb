# frozen_string_literal: true

require 'spec_helper'

describe 'PushHookPayload' do
  context 'with payload' do
    before do
      @payload = Github::Api::PushHookPayload.new(load_json_fixture('github_push_payload'))
    end

    it 'has a sha' do
      expect(@payload.sha).to eq('6d8cc7db8021d3dbf90a4ebd378d2ecb97c2bc25')
    end

    it 'has a message' do
      expect(@payload.message).to eq('The commit message')
    end

    it 'has a branch name' do
      expect(@payload.branch_name).to eq('test/branch_name')
    end

    it 'has an author name' do
      expect(@payload.author_name).to eq('Author Name')
    end

    it 'has an author email' do
      expect(@payload.author_email).to eq('author@email.com')
    end

    it 'has a repo name' do
      expect(@payload.repository_name).to eq('reponame')
    end

    it 'has a repo owner name' do
      expect(@payload.repository_owner_name).to eq('OwnerName')
    end

    it 'has a repo path' do
      expect(@payload.repository_path).to eq('OwnerName/reponame')
    end

    it 'can create git branch data' do
      expect(@payload.git_branch_data.author_name).to eq('Author Name')
      expect(@payload.git_branch_data.author_email).to eq('author@email.com')
      expect(@payload.git_branch_data.repository_name).to eq('OwnerName/reponame')
      expect(@payload.git_branch_data.name).to eq('test/branch_name')
    end
  end
end
