# frozen_string_literal: true

class Service < ActiveRecord::Base
  DEFAULT_ANCESTOR_BRANCH = 'master'

  fields do
    name :string, limit: 255, index: true, unique: true, validates: { presence: true, uniqueness: true }
    ref  :string, limit: 255, default: DEFAULT_ANCESTOR_BRANCH, validates: { presence: true }
  end

  has_many :pushes, inverse_of: :service
end
