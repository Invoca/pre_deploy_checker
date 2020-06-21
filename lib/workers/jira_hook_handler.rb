class JiraHookHandler
  PROCESSING_QUEUE = 'jira_hook_handler'.freeze

  def queue!(payload)
    jira_client = JIRA::Client.new
    Rails.logger.info('Processing JIRA hook')
    jira_data = JIRA::Resource::IssueFactory.new(jira_client).build(payload['issue'])
    Rails.logger.info(payload)

    pushes = Push.with_jira_issue(jira_data.key)
    if pushes.any?
      jira_issue = JiraIssue.create_from_jira_data(jira_client, jira_data)
      if jira_issue.changed.empty?
        Rails.logger.info("Ignoring JIRA issue #{jira_data.key} because it did not contain any material changes")
      else
        Rails.logger.info("Queueing #{pushes.length} pushes related to JIRA issue #{jira_data.key}")
        pushes.each do |push|
          PushChangeHandler.new.submit_push_for_processing!(push)
        end
      end
    else
      Rails.logger.info("Ignoring JIRA issue #{jira_data.key} because it is not related to any existing pushes")
    end
  end
  handle_asynchronously(:queue!, queue: PROCESSING_QUEUE)
end
