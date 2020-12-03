# frozen_string_literal: true

module Github
  module Api
    class PushHookPayload
      def initialize(payload)
        @payload = payload.with_indifferent_access
      end

      def sha
        head_commit[:id]
      end

      def message
        head_commit[:message]
      end

      def branch_name
        Git::GitBranch.name_from_ref(@payload[:ref])
      end

      def author_email
        author[:email]
      end

      def author_name
        author[:name]
      end

      def repository_name
        repository[:name]
      end

      def repository_owner_name
        repository_owner[:name]
      end

      def repository_path
        "#{repository_owner_name}/#{repository[:name]}"
      end

      def git_branch_data
        @git_branch_data ||= Git::GitBranch.new(repository_path,
                                                branch_name,
                                                Time.iso8601(head_commit[:timestamp]),
                                                author_name,
                                                author_email)
      end

      private

      def head_commit
        @payload[:head_commit] || (raise 'Payload does not include head commit')
      end

      def author
        head_commit[:author] || (raise 'Payload does not include head commit author')
      end

      def repository
        @payload[:repository] || (raise 'Payload does not include repository')
      end

      def repository_owner
        repository[:owner] || (raise 'Payload does not include repository owner')
      end
    end
  end
end
