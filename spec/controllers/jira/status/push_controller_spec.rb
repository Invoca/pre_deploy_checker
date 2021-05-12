# frozen_string_literal: true

require 'spec_helper'

describe Jira::Status::PushController, type: :controller do
  render_views

  before(:each) do
    user = User.create!(name: 'First Last', email: 'flast@email.com')
    repo = Repository.new(name: 'master')
    repo.save!
    @branch = Branch.create!(author: user, repository: repo, name: 'feature_branch', git_updated_at: Time.now)
    @commit = Commit.create!(sha: '12345678', message: 'This is the head commit', author: user)
    @rs_service = Service.find_or_create_by!(name: 'rs_west', ref: 'a_whole_new_ref')
    @push = Push.create!(status: :success, branch: @branch, head_commit: @commit, service: @rs_service)
  end

  describe 'email' do
    after(:each) do
      DeployEmailInterceptor.clear_email
    end

    it 'sends an email and returns success for push' do
      allow(Time).to receive(:now).and_return(Time.gm(2020, 7, 4, 12, 0))
      get :deploy_email, params: { id: '12345678', service_name: 'rs_west' }
      expect(response).to have_http_status(302)
      expect(flash[:alert]).to match(/Email has been sent/)

      sent_email = DeployEmailInterceptor.intercepted_email
      expect(sent_email.to).to eq ['deploy@invoca.com']
      expect(sent_email.from).to eq ['deploy@invoca.com']
      expect(sent_email.subject).to eq("Web Deploy 07/04/20 05:00 -0700")
      expect(@push.reload.email_sent).to eq(true)
    end

    it 'doesnt send an email and returns success if email has already been sent' do
      @push.update(email_sent: true)
      get :deploy_email, params: { id: '12345678', service_name: 'rs_west' }
      expect(response).to have_http_status(302)
      expect(flash[:alert]).to match(/Email was already sent/)
      expect(DeployEmailInterceptor.intercepted_email).to eq(nil)
    end

    it 'does not set email_sent to true if sending the email raises an error' do
      exception = ArgumentError.new("Bad args")
      expect(DeployMailer).to receive(:deployment_email) { raise exception }

      expect { get :deploy_email, params: { id: '12345678', service_name: 'rs_west' } }.to raise_error(exception)
      expect(@push.reload.email_sent).to eq(false)
    end

    it 'redirects to summary page if not commit not found with sha matching id' do
      get :deploy_email, params: { id: 'abc', service_name: 'rs_west' }
      expect(response).to have_http_status(302)
      expect(response.redirect_url).to eq('http://test.host/400')
    end
  end

  describe 'view routes' do
    let(:web_service) { Service.find_or_create_by!(name: 'web') }
    let(:web_push) { Push.create!(status: :success, branch: @branch, head_commit: @commit, service: web_service) }
    let(:rs_west_push) { Push.create!(status: :success, branch: @branch, head_commit: @commit, service: @rs_service) }

    describe 'branch' do
      describe "with service name" do
        subject { get :branch, params: { branch: 'feature_branch', service_name: "rs_west" } }

        it "renders edit page for service provided" do
          dbl = double("ActiveRecord Relation", first!: @branch, for_service: [rs_west_push])
          expect(Branch).to receive(:where).and_return(dbl)
          expect(@branch).to receive(:pushes).and_return(dbl)
          expect(dbl).to receive(:for_service).with("rs_west")

          expect(subject).to render_template("jira/status/push/edit")
          expect(assigns(:push)).to eq(rs_west_push)
          expect(assigns(:push)).to be_persisted
        end
      end

      describe "without service name" do
        subject { get :branch, params: { branch: 'feature_branch' } }

        it "renders edit page for web service" do
          dbl = double("ActiveRecord Relation", first!: @branch, for_service: [web_push])
          expect(Branch).to receive(:where).and_return(dbl)
          expect(@branch).to receive(:pushes).and_return(dbl)
          expect(dbl).to receive(:for_service).with("web")

          expect(subject).to render_template("jira/status/push/edit")
          expect(assigns(:push)).to eq(web_push)
          expect(assigns(:push)).to be_persisted
        end
      end
    end

    describe 'summary' do
      [["web", :web_push], ["rs_west", :rs_west_push]].each do |service_name, push_for_service|
        it "renders summary page for service #{service_name}" do
          dbl = double("ActiveRecord Relation", first!: @branch, for_service: [web_push, rs_west_push])
          expect(Branch).to receive(:where).with(name: "master").and_return(dbl)
          expect(@branch).to receive(:pushes).and_return(dbl)
          expect(dbl).to receive(:for_service).with(service_name).and_return([send(push_for_service)])

          expect(get(:summary, params: { service_name: service_name })).to render_template("jira/status/push/summary")
          expect(assigns(:push)).to eq(send(push_for_service))
          expect(assigns(:push)).to be_persisted
        end
      end

      it "defaults service_name to web" do
        dbl = double("ActiveRecord Relation", first!: @branch, for_service: [rs_west_push, web_push])
        expect(Branch).to receive(:where).with(name: "master").and_return(dbl)
        expect(@branch).to receive(:pushes).and_return(dbl)
        expect(dbl).to receive(:for_service).with("web").and_return([web_push])

        expect(get(:summary)).to render_template("jira/status/push/summary")
        expect(assigns(:push)).to eq(web_push)
        expect(assigns(:push)).to be_persisted
      end
    end

    # TODO: luan/phoenix - improve test coverage for this action
    describe 'update' do
      [["web", :web_push], ["rs_west", :rs_west_push]].each do |service_name, push_for_service|
        describe "when #{service_name}" do
          it "redirects to edit page with appropriate params" do
            dbl = double("ActiveRecord Relation", first!: send(push_for_service))
            expect(Push).to receive(:for_commit_and_service).with(@commit.sha, service_name).and_return(dbl)

            expect(post(:update, params: { id: @commit.sha, service_name: service_name }))
              .to redirect_to({ action: :edit, id: @commit.sha, service_name: service_name })
          end
        end
      end
    end

    describe "edit" do
      describe "with service name" do
        subject { post :edit, params: { id: @commit.sha, service_name: "web" } }

        it "renders edit page with appropriate params" do
          dbl = double("ActiveRecord Relation", first!: web_push)
          expect(Push).to receive(:for_commit_and_service).with(@commit.sha, "web").and_return(dbl)

          expect(subject).to render_template("jira/status/push/edit")
          expect(assigns(:push)).to eq(web_push)
          expect(assigns(:push)).to be_persisted
        end
      end

      describe "without service name" do
        subject { post :edit, params: { id: @commit.sha } }

        it "renders edit page for web service" do
          dbl = double("ActiveRecord Relation", first!: web_push)
          expect(Push).to receive(:for_commit_and_service).with(@commit.sha, "web").and_return(dbl)

          expect(subject).to render_template("jira/status/push/edit")
          expect(assigns(:push)).to eq(web_push)
          expect(assigns(:push)).to be_persisted
        end
      end
    end
  end
end
