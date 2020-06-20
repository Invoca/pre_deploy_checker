class Branch < ActiveRecord::Base
  include GitModels::Branch

  has_many :pushes, class_name: 'Push', dependent: :destroy
end
