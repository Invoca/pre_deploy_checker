require 'spec_helper'

describe 'User' do
  def jira_user
    @jira_user ||= JIRA::Resource::UserFactory.new(jira_client).build(
      load_json_fixture('jira_issue_response')['fields']['assignee']
    )
  end

  it 'can create be constructed from jira data' do
    user = User.create_from_jira_data!(jira_client, jira_user)

    expect(user.name).to eq('Author Name')
    expect(user.email).to eq('aname@email.com')
    expect(user.created_at).not_to be_nil
    expect(user.updated_at).not_to be_nil
  end
end
