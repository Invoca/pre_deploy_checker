class PushChangeHandler
  include Rails.application.routes.url_helpers

  PROCESSING_QUEUE = 'push_handler'.freeze
  CONTEXT_NAME = 'Pre-Deploy Checker'.freeze
  STATE_DESCRIPTIONS = {
    Github::Api::Status::STATE_PENDING => 'Processing...',
    Github::Api::Status::STATE_SUCCESS => 'OK to deploy',
    Github::Api::Status::STATE_FAILED => 'Has unapproved errors'
  }.freeze

  def process_push!(push_id)
    Rails.logger.info("Processing push id #{push_id}")
    push = PushManager.process_push!(Push.find(push_id))
    set_status_for_push!(push)
  end
  handle_asynchronously(:process_push!, queue: PROCESSING_QUEUE)

  def submit_push_for_processing!(push)
    push.status = Github::Api::Status::STATE_PENDING
    push.save!
    set_status_for_push!(push)
    process_push!(push.id)
  end

  private

  def set_status_for_push!(push) # rubocop:disable Naming/AccessorMethodName
    if push.service.name == "web"
      api = Github::Api::Status.new(Rails.application.secrets.github_user_name,
                                    Rails.application.secrets.github_password)
      api.set_status(push.branch.repository.name,
                     push.head_commit.sha,
                     CONTEXT_NAME,
                     push.status,
                     STATE_DESCRIPTIONS[push.status.to_sym],
                     url_for(controller: '/jira/status/push', action: :edit, id: push.head_commit.sha))
    end
  end
end
