# frozen_string_literal: true

class GithubPushHookHandler
  PROCESSING_QUEUE = 'github_push_handler'

  def queue!(push_hook_payload)
    Rails.logger.info('Processing GitHub hook')
    payload = Github::Api::PushHookPayload.new(push_hook_payload)
    Rails.logger.info(payload)

    if should_ignore_push?(payload)
      Rails.logger.info("Ignoring branch #{payload.branch_name} because it is in the ignore list")
    elsif should_include_push?(payload)
      Rails.logger.info("Queueing push to branch #{payload.branch_name}")
      pushes = Push.create_from_github_data!(payload)
      pushes.each do |push|
        PushChangeHandler.new.submit_push_for_processing!(push)
      end
    else
      Rails.logger.info("Ignoring branch #{payload.branch_name} because it is not in the include list")
    end
  end
  handle_asynchronously(:queue!, queue: PROCESSING_QUEUE)

  private

  def should_ignore_push?(payload)
    GlobalSettings.jira.ignore_branches.include_regexp?(payload.branch_name, regexp_options: Regexp::IGNORECASE)
  end

  def should_include_push?(payload)
    if GlobalSettings.jira.only_branches.any?
      GlobalSettings.jira.only_branches.include_regexp?(payload.branch_name, regexp_options: Regexp::IGNORECASE)
    else
      true
    end
  end
end
