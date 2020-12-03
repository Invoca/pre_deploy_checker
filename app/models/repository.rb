# frozen_string_literal: true

class Repository < ActiveRecord::Base
  fields do
    name :string, limit: 1024, index: true, unique: true, validates: { uniqueness: true }
    timestamps
  end

  has_many :branches, class_name: 'Branch', inverse_of: :repository, dependent: :destroy
end
