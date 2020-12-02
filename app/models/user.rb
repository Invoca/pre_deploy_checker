# frozen_string_literal: true

class User < ActiveRecord::Base
  fields do
    name  :string, limit: 255, index: true, unique: true, validates: { uniqueness: { scope: :email } }
    email :string, limit: 255

    timestamps
  end

  has_many :branches, class_name: 'Branch',    foreign_key: 'author_id',   inverse_of: :author
  has_many :commits,  class_name: 'Commit',    foreign_key: 'author_id',   inverse_of: :author

  class << self
    def users_with_emails(email_filter_list)
      # if filter is empty, return all users, otherwise only return users whose emails are in the list
      if email_filter_list.empty?
        all
      else
        all.select { |user| email_filter_list.include?(user.email.downcase) }
      end
    end

    # TODO: refactor this out
    def create_from_jira_data!(jira_user_data)
      # Uses fake email to guarantee uniqueness
      name = jira_user_data.displayName
      User.find_or_create_by!(name: name, email: fake_email_from_name(name))
    end

    private

    # Converts (First Last) => flast@email.com
    def fake_email_from_name(display_name)
      name_arr = display_name.downcase.split(' ')
      "#{name_arr.first.first}#{name_arr.last}@email.com"
    end
  end
end
