# frozen_string_literal: true

require_relative 'application_mailer'

class DeployMailer < ApplicationMailer
  default from: 'deploy@invoca.com'

  def deployment_email(jira_issues)
    @jira_issues = jira_issues
    now = Time.now.in_time_zone('Pacific Time (US & Canada)') # since `config.time_zone =` not working
    mail(to: 'deploy@invoca.com', subject: "Web Deploy #{now.strftime('%m/%d/%y %H:%M %z')}")
  end
end
