# frozen_string_literal: true

class Department < ApplicationRecord
  # Enums
  enum :department_type, { general: 0, management: 1 }

  # Associations
  has_many :users, dependent: :nullify

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :description, length: { maximum: 1000 }
  validates :department_type, presence: true

  # Scopes
  scope :by_type, ->(type) { where(department_type: type) }

  def user_count
    users.count
  end

  def type_display_name
    {
      'general' => '一般部署',
      'management' => '管理部署',
    }[department_type]
  end
end
