# frozen_string_literal: true

class Application < ApplicationRecord
  include AASM

  belongs_to :user
  has_many :approvals, as: :approvable, dependent: :destroy

  # Enums
  enum :application_type, {
    absence: 0,
    late: 1,
    early_leave: 2,
    shift_change: 3,
  }

  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2,
    canceled: 3,
  }

  # AASM 状態管理
  aasm column: :status, enum: true, whiny_persistence: true do
    state :pending, initial: true
    state :approved
    state :rejected
    state :canceled

    event :approve_final do
      transitions from: :pending, to: :approved
    end

    event :reject_final do
      transitions from: :pending, to: :rejected
    end

    event :cancel do
      transitions from: :pending, to: :canceled, after: :cancel_pending_approvals
    end

    event :resubmit do
      transitions from: [:rejected, :canceled], to: :pending, after: :recreate_approval_records
    end
  end

  # Callbacks
  after_create :create_approval_records

  # Validations
  validates :application_type, presence: true
  validates :application_date, presence: true
  validates :reason, presence: true, length: { minimum: 5, maximum: 500 }
  validates :status, presence: true

  # Scopes
  scope :for_date, ->(date) { where(application_date: date) }
  scope :for_month, ->(year, month) { where(application_date: Date.new(year, month, 1)..Date.new(year, month, -1)) }
  scope :pending_approval, -> { where(status: :pending) }
  scope :approved, -> { where(status: :approved) }
  scope :by_type, ->(type) { where(application_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  # Helper methods
  def application_type_display_name
    {
      'absence' => '欠勤申請',
      'late' => '遅刻申請',
      'early_leave' => '早退申請',
      'shift_change' => 'シフト変更申請',
    }[application_type]
  end

  def status_display_name
    {
      'pending' => '承認待ち',
      'approved' => '承認済み',
      'rejected' => '却下',
      'canceled' => '取り消し',
    }[status]
  end

  def summary
    "#{application_type_display_name} - #{application_date.strftime('%Y/%m/%d')}"
  end

  # Class methods
  def self.for_user_and_date(user, date)
    where(user: user, application_date: date)
  end

  def self.pending_count_for_user(user)
    where(user: user, status: :pending).count
  end

  def self.this_month_for_user(user)
    current_date = Date.current
    for_month(current_date.year, current_date.month).where(user: user)
  end

  # 承認システム関連メソッド
  def department_approval
    approvals.find_by(approval_type: :department)
  end

  # 部署承認のみで完了
  def check_and_update_status!
    return unless pending?

    # approvals関連をリロードして最新の状態を取得
    approvals.reload
    dept_approval = department_approval

    if dept_approval&.approved?
      approve_final! if may_approve_final?
    elsif dept_approval&.rejected?
      reject_final! if may_reject_final?
    end
  end

  def can_resubmit?
    rejected? || canceled?
  end

  def can_cancel?
    pending?
  end

  private

  # 取り消し時に承認待ちの承認レコードを削除
  def cancel_pending_approvals
    approvals.where(status: :pending).destroy_all
  end

  # AASM submit イベント後に承認レコードを作成（部署承認のみ）
  def create_approval_records
    # 既存の承認レコードがなければ作成
    unless department_approval
      approvals.create!(
        approver_id: find_department_approver_id,
        approval_type: :department,
        status: :pending
      )
    end
  rescue StandardError => e
    Rails.logger.error("Application approval records creation failed: #{e.message}")
    raise ActiveRecord::Rollback
  end

  # 再申請時に古い承認レコードを削除して新しいものを作成
  def recreate_approval_records
    approvals.destroy_all
    create_approval_records
  end

  def find_department_approver_id
    # 部署担当者（department_manager権限）を取得
    department = user.department
    return User.with_role(:department_manager).first&.id unless department

    department_manager_role = Role.find_by(name: :department_manager)
    return User.with_role(:department_manager).first&.id unless department_manager_role

    department.users.joins(:user_roles)
              .where(user_roles: { role_id: department_manager_role.id })
              .first&.id || User.with_role(:department_manager).first&.id
  end
end
