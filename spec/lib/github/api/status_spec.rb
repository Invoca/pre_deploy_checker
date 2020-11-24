# frozen_string_literal: true

require 'spec_helper'

describe 'Status' do
  EXPECTED_URL = 'https://api.github.com/repos/owner/repo/statuses/9999b61a5393432301de18960686226379d76999'

  def mock_sucess_response_body(state)
    {
      'created_at' => '2012-07-20T01:19:13Z',
      'updated_at' => '2012-07-20T01:19:13Z',
      'state' => state.to_s,
      'target_url' => 'https://ci.example.com/1000/output',
      'description' => 'Build has completed successfully',
      'id' => 1,
      'url' => 'https://api.github.com/repos/octocat/Hello-World/statuses/1',
      'context' => 'continuous-integration/jenkins',
      'creator' => {
        'login' => 'octocat',
        'id' => 1,
        'avatar_url' => 'https://github.com/images/error/octocat_happy.gif',
        'gravatar_id' => '',
        'url' => 'https://api.github.com/users/octocat',
        'html_url' => 'https://github.com/octocat',
        'followers_url' => 'https://api.github.com/users/octocat/followers',
        'following_url' => 'https://api.github.com/users/octocat/following{/other_user}',
        'gists_url' => 'https://api.github.com/users/octocat/gists{/gist_id}',
        'starred_url' => 'https://api.github.com/users/octocat/starred{/owner}{/repo}',
        'subscriptions_url' => 'https://api.github.com/users/octocat/subscriptions',
        'organizations_url' => 'https://api.github.com/users/octocat/orgs',
        'repos_url' => 'https://api.github.com/users/octocat/repos',
        'events_url' => 'https://api.github.com/users/octocat/events{/privacy}',
        'received_events_url' => 'https://api.github.com/users/octocat/received_events',
        'type' => 'User',
        'site_admin' => false
      }
    }.to_json
  end

  def mock_error_response
    {
      'message' => 'No commit found for SHA: 9999b61a5393432301de18960686226379d76999',
      'documentation_url' => 'https://developer.github.com/v3/repos/statuses/'
    }.to_json
  end

  def send_set_status_request(state)
    api = Github::Api::Status.new('test_user', 'test_password')
    api.set_status('owner/repo',
                   '9999b61a5393432301de18960686226379d76999',
                   'JIRA Checker',
                   state,
                   'Things are a-ok',
                   'http://moreinfohere.com')
  end

  Github::Api::Status::STATES.each do |state|
    it "can set status to #{state}" do
      stub_request(:post, EXPECTED_URL) \
        .with(basic_auth: ['test_user', 'test_password']) \
        .to_return(status: 201, body: mock_sucess_response_body(state))

      send_set_status_request(state)
    end
  end

  it 'raises for non 201 responses' do
    stub_request(:post, EXPECTED_URL) \
      .with(basic_auth: ['test_user', 'test_password']) \
      .to_return(status: 422, body: mock_error_response)

    expect { send_set_status_request(Github::Api::Status::STATE_SUCCESS) }.to raise_exception(Net::HTTPClientException)
  end
end
