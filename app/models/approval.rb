# frozen_string_literal: true

class Approval < ApplicationRecord
  belongs_to :approvable, polymorphic: true
  belongs_to :approver, class_name: 'User'

  # Enums
  enum :approval_type, {
    department_approval: 0,
    labor_approval: 1,
  }

  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2,
  }

  # Validations
  validates :approval_type, presence: true
  validates :status, presence: true
  validates :comment, length: { maximum: 500 }
  validates :approver_id, uniqueness: {
    scope: [:approvable_type, :approvable_id, :approval_type],
    message: 'この承認者は既にこの項目を承認済みです',
  }

  # Callbacks
  before_save :set_approved_at, if: :status_changed_to_approved_or_rejected?

  # Scopes
  scope :pending_approval, -> { where(status: :pending) }
  scope :completed, -> { where(status: [:approved, :rejected]) }
  scope :department_approvals, -> { where(approval_type: :department_approval) }
  scope :labor_approvals, -> { where(approval_type: :labor_approval) }
  scope :recent, -> { order(created_at: :desc) }

  # Helper methods
  def approval_type_display_name
    case approval_type
    when 'department_approval'
      '部署承認'
    when 'labor_approval'
      '労務承認'
    end
  end

  def status_display_name
    {
      'pending' => '承認待ち',
      'approved' => '承認済み',
      'rejected' => '却下',
    }[status]
  end

  def approved_or_rejected?
    approved? || rejected?
  end

  def pending_approval?
    pending?
  end

  def approval_summary
    "#{approval_type_display_name}: #{status_display_name}"
  end

  def approver_name
    approver&.display_name || '不明'
  end

  def approvable_summary
    case approvable_type
    when 'Shift'
      "#{approvable.display_period}のシフト"
    when 'Application'
      approvable.summary
    when 'Attendance'
      "#{approvable.date.strftime('%Y/%m/%d')}の勤怠"
    else
      "#{approvable_type}(ID: #{approvable_id})"
    end
  end

  # Class methods
  def self.pending_for_approver(user)
    if user.department_manager?
      where(approval_type: :department_approval, status: :pending)
    elsif user.hr_manager?
      where(approval_type: :labor_approval, status: :pending)
    elsif user.system_admin?
      where(status: :pending)
    else
      none
    end
  end

  def self.create_for_approvable(approvable)
    approvals = []
    approvals.concat(create_department_approvals(approvable))
    approvals.concat(create_labor_approvals(approvable))
    approvals
  end

  def self.create_department_approvals(approvable)
    return [] unless requires_department_approval?(approvable)

    [new(
      approvable: approvable,
      approval_type: :department_approval,
      status: :pending
    )]
  end

  def self.create_labor_approvals(approvable)
    return [] unless requires_labor_approval?(approvable)

    [new(
      approvable: approvable,
      approval_type: :labor_approval,
      status: :pending
    )]
  end

  def self.requires_department_approval?(approvable)
    # シフト、申請、勤怠は部署承認が必要
    %w[Shift Application Attendance].include?(approvable.class.name)
  end

  def self.requires_labor_approval?(approvable)
    # シフト、申請は労務承認も必要
    %w[Shift Application].include?(approvable.class.name)
  end

  private

  def status_changed_to_approved_or_rejected?
    status_changed? && approved_or_rejected?
  end

  def set_approved_at
    self.approved_at = Time.current
  end
end
