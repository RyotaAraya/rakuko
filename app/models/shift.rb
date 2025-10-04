# frozen_string_literal: true

class Shift < ApplicationRecord
  include AASM

  belongs_to :user
  has_many :shift_schedules, dependent: :destroy
  has_many :approvals, as: :approvable, dependent: :destroy

  # Enums
  enum :status, {
    draft: 0,
    submitted: 1,
    department_approved: 2,
    labor_approved: 3,
    fully_approved: 4,
    rejected: 5,
  }

  # Validations
  validates :year, presence: true, numericality: { greater_than: 2020, less_than: 2100 }
  validates :month, presence: true, numericality: { in: 1..12 }
  validates :status, presence: true
  validates :user_id, uniqueness: { scope: [:year, :month], message: 'すでにこの年月のシフトが存在します' }

  # Scopes
  scope :for_month, ->(year, month) { where(year: year, month: month) }
  scope :pending_approval, -> { where(status: [:submitted, :department_approved, :labor_approved]) }

  # AASM State Machine
  aasm column: :status, enum: true do
    state :draft, initial: true
    state :submitted
    state :department_approved
    state :labor_approved
    state :fully_approved
    state :rejected

    event :submit do
      transitions from: :draft, to: :submitted
    end

    event :department_approve do
      transitions from: :submitted, to: :department_approved
    end

    event :labor_approve do
      transitions from: [:submitted, :department_approved], to: :labor_approved
    end

    event :fully_approve do
      transitions from: [:department_approved, :labor_approved], to: :fully_approved
    end

    event :reject do
      transitions from: [:submitted, :department_approved, :labor_approved], to: :rejected
    end

    event :reset_to_draft do
      transitions from: :rejected, to: :draft
    end
  end

  # Helper methods
  def display_period
    "#{year}年#{month}月"
  end

  def violation_warnings_array
    return [] if violation_warnings.blank?

    JSON.parse(violation_warnings)
  rescue JSON::ParserError
    []
  end

  def add_violation_warning(warning)
    warnings = violation_warnings_array
    warnings << warning
    self.violation_warnings = warnings.to_json
  end

  def violations?
    violation_warnings_array.any?
  end

  def status_display_name
    {
      'draft' => '下書き',
      'submitted' => '提出済み',
      'department_approved' => '部署承認済み',
      'labor_approved' => '労務承認済み',
      'fully_approved' => '最終承認済み',
      'rejected' => '却下',
    }[status]
  end
end
