class Department < ApplicationRecord
  # Enums
  enum department_type: { general: 0, labor: 1, management: 2 }

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
    case department_type
    when 'general'
      '一般部署'
    when 'labor'
      '労務部署'
    when 'management'
      '管理部署'
    end
  end
end
