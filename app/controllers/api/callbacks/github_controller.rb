# frozen_string_literal: true

module Api
  module Callbacks
    class GithubController < ApplicationController
      protect_from_forgery with: :null_session
      before_action :parse_request

      def push
        Rails.logger.info(
          "Received Github push callback. Adding to delayed job queue. Current queue depth: #{Delayed::Job.count}"
        )
        GithubPushHookHandler.new.queue!(@payload)
        head(:ok)
      end

      private

      def parse_request
        @payload = JSON.parse(request.body.read)
      rescue JSON::ParserError
        render(plain: 'Invalid JSON', status: :bad_request)
      end
    end
  end
end
