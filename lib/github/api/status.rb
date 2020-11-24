# frozen_string_literal: true

module Github
  module Api
    class Status
      STATE_SUCCESS = :success
      STATE_PENDING = :pending
      STATE_FAILED = :failure
      STATES = [STATE_SUCCESS, STATE_PENDING, STATE_FAILED].freeze

      def initialize(username, password)
        @username = username
        @password = password
      end

      def set_status(repo_path, sha, context, state, description, url)
        Rails.logger.info("Setting #{context} status to #{state} for #{repo_path}/#{sha}")
        body = {
          state: state.to_s,
          target_url: url.to_s,
          description: description,
          context: context
        }

        uri = URI.parse("https://api.github.com/repos/#{repo_path}/statuses/#{sha}")
        request = Net::HTTP::Post.new(uri.path)
        request.basic_auth(@username, @password)
        request.body = body.to_json

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        response = http.request(request)

        if response.is_a?(Net::HTTPCreated)
          JSON.parse(response.body)
        else
          response.error!
        end
      end
    end
  end
end
