class UserRole < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :role

  # Validations
  validates :user_id, presence: true
  validates :role_id, presence: true
  validates :user_id, uniqueness: { scope: :role_id, message: 'すでにこの権限が割り当てられています' }

  # Delegations
  delegate :display_name, to: :role, prefix: true
  delegate :name, to: :role, prefix: true
end
