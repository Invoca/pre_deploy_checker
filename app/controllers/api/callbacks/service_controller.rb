# frozen_string_literal: true

module Api
  module Callbacks
    class ServiceController < ApplicationController
      protect_from_forgery with: :null_session
      before_action :authorize
      before_action :find_service

      class Unauthorized < StandardError; end

      rescue_from Unauthorized do |ex|
        render json: { error: "Unauthorized Request: #{ex.message}" }, status: 401
      end

      def update
        Rails.logger.info("Received DeployBot deploy callback. Updating #{params[:service_name]} with new ref #{params[:ref]}")
        @service.update!(ref: params[:ref])
        render json: { body: {} }, status: 200
      end

      private

      def find_service
        @service = Service.find_by!(name: params[:service_name])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not Found" }, status: 404
      end

      def authorize
        if (mac = request.authorization.presence)
          digest = digest_request_parameters(InvocaSecrets['pre_deploy_checker', 'api', 'auth_key'])
          digest == mac or raise Unauthorized, "Authorization Header '#{mac}' does not match Computed Digest '#{digest}'"
        else
          raise Unauthorized, "Missing Authorization header"
        end
      end

      def digest_request_parameters(key)
        data = request.request_parameters.sort.to_s
        Rails.logger.info("auth body from pre-deploy-checker: #{data}")
        Rails.logger.info("params from pre-deploy-checker: #{params}")
        puts "auth body from pre-deploy-checker: #{data}"
        OpenSSL::HMAC.hexdigest('SHA256', key, data)
      end
    end
  end
end
