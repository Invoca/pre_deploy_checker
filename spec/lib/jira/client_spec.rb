# frozen_string_literal: true

require 'spec_helper'

describe 'JIRA::ClientWrapper' do
  def jira_issue_response
    @jira_issue_response ||= load_fixture_file('jira_issue_response.json')
  end

  def jira_jql_query_response
    @jira_jql_query_response ||= load_fixture_file('jira_jql_query_response.json')
  end

  it 'can be created' do
    settings = {
      'site' => 'https://www.jira.com',
      'consumer_key' => 'fake_key',
      'access_token' => 'fake_access_token',
      'access_key' => 'fake_access_key',
      'private_key_file' => Rails.root.join('spec', 'fixtures', 'rsakey.pem')
    }
    client = JIRA::ClientWrapper.new(settings)
    expect(client).not_to be_nil
  end

  context 'issues' do
    before do
      settings = {
        site: 'https://www.jira.com',
        consumer_key: 'fake_key',
        access_token: 'fake_access_token',
        access_key: 'fake_access_key',
        private_key_file: Rails.root.join('spec', 'fixtures', 'rsakey.pem')
      }
      @client = JIRA::ClientWrapper.new(settings)
    end

    context 'find_issue_by_key' do
      it 'can find an issue' do
        stub_request(:get, /.*/).to_return(status: 200, body: jira_issue_response)

        expect(@client.find_issue_by_key('ISSUE-1234')).not_to be_nil
      end

      it 'returns nil if the issue does not exist' do
        stub_request(:get, /.*/).to_return(status: 404, body: 'Not Found')

        expect(@client.find_issue_by_key('ISSUE-1234')).to be_nil
      end
    end

    context 'find_issue_by_jql' do
      it 'can find issues' do
        stub_request(:get, /.*/).to_return(status: 200, body: jira_jql_query_response)

        expect(@client.find_issues_by_jql('project in (WEB, TECH, STORY, OPS)')).not_to be_nil
      end

      it 'returns empty array if query finds no issues' do
        stub_request(:get, /.*/).to_return(status: 200, body: '{"issues": []}')

        expect(@client.find_issues_by_jql('project in (WEB, TECH, STORY, OPS)')).to match_array([])
      end
    end
  end
end
