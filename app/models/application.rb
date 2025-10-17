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
    draft: 0,
    pending: 1,
    approved: 2,
    rejected: 3,
  }

  # AASM 状態管理
  aasm column: :status, enum: true do
    state :draft, initial: true
    state :pending
    state :approved
    state :rejected

    event :submit do
      transitions from: :draft, to: :pending, after: :create_approval_records
    end

    event :approve_final do
      transitions from: :pending, to: :approved
    end

    event :reject_final do
      transitions from: :pending, to: :rejected
    end

    event :return_to_draft do
      transitions from: :pending, to: :draft
    end
  end

  # Validations
  validates :application_type, presence: true
  validates :application_date, presence: true
  validates :reason, presence: true, length: { minimum: 10, maximum: 500 }
  validates :status, presence: true
  validate :time_fields_for_type
  validate :application_date_not_past
  validate :logical_time_order

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
      'draft' => '下書き',
      'pending' => '承認待ち',
      'approved' => '承認済み',
      'rejected' => '却下',
    }[status]
  end

  def time_display
    case application_type
    when 'absence'
      '終日'
    when 'late'
      "#{start_time.strftime('%H:%M')}から出勤"
    when 'early_leave'
      "#{end_time.strftime('%H:%M')}に早退"
    when 'shift_change'
      "#{start_time.strftime('%H:%M')} - #{end_time.strftime('%H:%M')}"
    end
  end

  def requires_times?
    %w[late early_leave shift_change].include?(application_type)
  end

  def requires_start_time?
    %w[late shift_change].include?(application_type)
  end

  def requires_end_time?
    %w[early_leave shift_change].include?(application_type)
  end

  def affects_attendance?
    %w[absence late early_leave].include?(application_type)
  end

  def summary
    "#{application_type_display_name} - #{application_date.strftime('%Y/%m/%d')} (#{time_display})"
  end

  def can_be_edited?
    pending? && application_date > Date.current
  end

  def can_be_cancelled?
    pending? && application_date > Date.current
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

  # 並列承認システム関連メソッド
  def department_approval
    approvals.find_by(approval_type: :department)
  end

  def labor_approval
    approvals.find_by(approval_type: :labor)
  end

  # 並列承認システム: 両方承認されたら approved に
  def check_and_update_status!
    return unless pending?

    dept_approved = department_approval&.approved?
    labor_approved = labor_approval&.approved?

    if dept_approved && labor_approved
      approve_final! if may_approve_final?
    elsif department_approval&.rejected? || labor_approval&.rejected?
      reject_final! if may_reject_final?
    end
  end

  private

  # AASM submit イベント後に承認レコードを作成
  def create_approval_records
    # 既存の承認レコードがなければ作成
    unless department_approval
      approvals.create!(
        approver_id: find_department_approver_id,
        approval_type: :department,
        status: :pending
      )
    end

    unless labor_approval
      approvals.create!(
        approver_id: find_labor_approver_id,
        approval_type: :labor,
        status: :pending
      )
    end
  rescue StandardError => e
    Rails.logger.error("Application approval records creation failed: #{e.message}")
    raise ActiveRecord::Rollback
  end

  def find_department_approver_id
    # 部署担当者（department_manager権限）を取得
    user.department&.users&.joins(:user_roles)
        &.where(user_roles: { role_id: Role.find_by(name: :department_manager)&.id })
        &.first&.id || User.with_role(:department_manager).first&.id
  end

  def find_labor_approver_id
    # 労務担当者（hr_manager権限）を取得
    User.with_role(:hr_manager).first&.id
  end

  def time_fields_for_type
    send("validate_#{application_type}_times")
  end

  def validate_absence_times
    # 欠勤は時刻不要
    errors.add(:start_time, '欠勤申請では開始時刻は不要です') if start_time.present?
    errors.add(:end_time, '欠勤申請では終了時刻は不要です') if end_time.present?
  end

  def validate_late_times
    # 遅刻は開始時刻のみ必要
    errors.add(:start_time, '遅刻申請では開始時刻が必要です') if start_time.blank?
    errors.add(:end_time, '遅刻申請では終了時刻は不要です') if end_time.present?
  end

  def validate_early_leave_times
    # 早退は終了時刻のみ必要
    errors.add(:start_time, '早退申請では開始時刻は不要です') if start_time.present?
    errors.add(:end_time, '早退申請では終了時刻が必要です') if end_time.blank?
  end

  def validate_shift_change_times
    # シフト変更は両方必要
    errors.add(:start_time, 'シフト変更申請では開始時刻が必要です') if start_time.blank?
    errors.add(:end_time, 'シフト変更申請では終了時刻が必要です') if end_time.blank?
  end

  def application_date_not_past
    return if application_date.blank?

    errors.add(:application_date, '過去の日付は申請できません') if application_date < Date.current
  end

  def logical_time_order
    return unless start_time.present? && end_time.present?
    return if start_time < end_time

    errors.add(:end_time, '終了時刻は開始時刻より後に設定してください')
  end
end
