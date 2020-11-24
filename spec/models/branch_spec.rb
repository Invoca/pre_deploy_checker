# frozen_string_literal: true

require 'spec_helper'

describe 'Branch' do
  it 'can create be constructed from git data' do
    branch = GitModels::TestHelpers.create_branch
    expect(branch.name).to eq('path/branch')
    expect(branch.git_updated_at).not_to be_nil
    expect(branch.created_at).not_to be_nil
    expect(branch.updated_at).not_to be_nil
  end
end
