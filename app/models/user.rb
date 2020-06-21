class User < ActiveRecord::Base
  include GitModels::User

  class << self
    def create_from_jira_data!(jira_client, jira_user_data)
      # Uses fake email to guarantee uniqueness
      name = jira_user_data.displayName
      User.where(name: name, email: fake_email_from_name(name)).first_or_create!
    end

    private

    # Converts (First Last) => flast@email.com
    def fake_email_from_name(display_name)
      name_arr = display_name.downcase.split(' ')
      "#{name_arr.first.first}#{name_arr.last}@email.com"
    end
  end
end
