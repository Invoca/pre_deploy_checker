# frozen_string_literal: true

class Branch < ActiveRecord::Base
  fields do
    git_updated_at :datetime
    name :string, limit: 1024, validates: { uniqueness: { scope: :repository, message: 'Branch names must be unique within each repository' } }
    timestamps
  end

  # TODO: add unique scoped index for name field

  belongs_to :author,     class_name: 'User',       inverse_of: :branches, optional: false
  belongs_to :repository, class_name: 'Repository', inverse_of: :branches, optional: false

  has_many :pushes, class_name: 'Push', inverse_of: :branch, dependent: :destroy

  class << self
    def create_from_git_data!(branch_data)
      transaction do
        repository = Repository.find_or_create_by!(name: branch_data.repository_name)
        find_or_initialize_by(repository: repository, name: branch_data.name).tap do |branch|
          branch.git_updated_at = branch_data.last_modified_date
          branch.updated_at = Time.current # force updated time
          branch.author = User.find_or_create_by!(name: github_data.author_name, email: github_data.author_email)
          branch.save!
        end
      end
    end

    def branches_not_updated_since(checked_at_date)
      where('updated_at < ?', checked_at_date)
    end

    def from_repository(repository_name)
      joins(:repository).where(repository: { name: repository_name })
    end
  end

  def to_s
    name
  end

  def <=>(other)
    name <=> other.name
  end
end
