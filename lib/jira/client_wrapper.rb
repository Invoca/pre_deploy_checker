module JIRA
  class ClientWrapper < JIRA::Client
    def initialize(settings)
      client_options = {
        signature_method: 'RSA-SHA1',
        consumer_key: settings['consumer_key'],
        site: settings['site'],
        context_path: '',
        use_ssl: true,
        private_key_file: settings['private_key_file']
      }

      super(client_options)

      @request_client.set_access_token(settings['access_token'], settings['access_key'])
    end

    def find_issue_by_key(key)
      key or raise ArgumentError "invalid falsey key #{key.inspect}"
      self.Issue.find(key)
    rescue JIRA::HTTPError => ex
      if ex.response.code == '404'
        nil
      else
        raise
      end
    end

    def find_issues_by_jql(jql)
      self.Issue.jql(jql, max_results: 100)
    rescue JIRA::HTTPError => ex
      raise ex
    end
  end
end
