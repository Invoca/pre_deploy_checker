require 'spec_helper'

describe Api::Callbacks::GithubController, type: :controller do
  render_views

  describe 'POST #push' do
    it 'returns success if valid JSON' do
      post :push, body: load_fixture_file('github_push_payload.json')
      expect(response).to have_http_status(200)
      expect(Delayed::Job.count).to eq(1)
    end

    it 'returns bad request if not valid JSON' do
      post :push, body: 'This is not JSON'
      expect(response).to have_http_status(400)
      expect(Delayed::Job.count).to eq(0)
    end
  end
end
