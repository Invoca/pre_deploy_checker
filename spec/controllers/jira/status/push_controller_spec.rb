# frozen_string_literal: true

require 'spec_helper'

describe Jira::Status::PushController, type: :controller do
  render_views

  describe 'email' do
    before(:each) do
      user = User.create!(name: 'First Last', email: 'flast@email.com')
      repo = Repository.new(name: 'master')
      repo.save!
      branch = Branch.create!(author: user, repository: repo, name: 'feature_branch', git_updated_at: Time.now)
      commit = Commit.create!(sha: '12345678', message: 'This is the head commit', author: user)
      @push = Push.create!(status: :success, branch: branch, head_commit: commit)
    end

    after(:each) do
      DeployEmailInterceptor.clear_email
    end

    it 'sends an email and returns success for push' do
      get :deploy_email, params: { id: '12345678' }
      expect(response).to have_http_status(302)
      expect(flash[:alert]).to match(/Email has been sent/)

      sent_email = DeployEmailInterceptor.intercepted_email
      expect(sent_email.to).to eq ['deploy@invoca.com']
      expect(sent_email.from).to eq ['deploy@invoca.com']
      expect(sent_email.subject).to match(/Web Deploy #{Time.now.strftime('%m/%d/%y')}/)
      expect(@push.reload.email_sent).to eq(true)
    end

    it 'doesnt send an email and returns success if email has already been sent' do
      @push.update_attributes(email_sent: true)
      get :deploy_email, params: { id: '12345678' }
      expect(response).to have_http_status(302)
      expect(flash[:alert]).to match(/Email was already sent/)
      expect(DeployEmailInterceptor.intercepted_email).to eq(jira_client)
    end

    it 'does not set email_sent to true if sending the email raises an error' do
      exception = ArgumentError.new("Bad args")
      expect(DeployMailer).to receive(:deployment_email) { raise exception }

      expect { get :deploy_email, params: { id: '12345678' } }.to raise_error(exception)
      expect(@push.reload.email_sent).to eq(false)
    end

    it 'redirects to summary page if not commit not found with sha matchin id' do
      get :deploy_email, params: { id: 'abc' }
      expect(response).to have_http_status(302)
      expect(response.redirect_url).to eq('http://test.host/400')
    end
  end
end
