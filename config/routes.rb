# frozen_string_literal: true

Rails.application.routes.draw do
  # respond to root for load balancer health checks
  get '/', to: proc { [200, {}, ['OK']] }

  get '/400' => 'errors#bad_request'

  get '/404' => 'errors#not_found'

  get '/500' => 'errors#internal_server_error'

  get 'users/:id/unsubscribe/new' => 'users#new_unsubscribe'
  post 'users/:id/unsubscribe/create' => 'users#create_unsubscribe'

  resources :suppressions, except: [:show, :edit, :update, :destroy]

  # Push routes
  namespace 'jira' do
    namespace 'status' do
      # These require :service_name as a query string param
      resources :push, only: [:edit, :update]
    end
  end

  get  ':service_name/sha/:id'          => 'jira/status/push#edit'
  get  ':service_name/deploy_email/:id' => 'jira/status/push#deploy_email'

  # Optionally pass :service_name as a query string param, otherwise default to web
  get  'summary'        => 'jira/status/push#summary'
  get  'branch/:branch' => 'jira/status/push#branch'

  namespace 'api' do
    scope '/v1' do
      namespace 'callbacks' do
        match 'service/:service_name', to: 'service#update', via: :post
        scope '/github' do
          post '/push' => 'github#push'
        end
        scope '/jira' do
          post '/hook' => 'jira#hook'
        end
      end
    end
  end

  # catch all route
  match ':all' => 'errors#not_found', via: [:all]
end
