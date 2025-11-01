# frozen_string_literal: true

class MonthEndClosing < ApplicationRecord
  belongs_to :user
  belongs_to :closed_by, class_name: 'User', optional: true
  has_many :approvals, as: :approvable, dependent: :destroy

  # Enums
  enum :status, {
    open: 0,
    pending_approval: 1,
    closed: 2,
    locked: 3,
  }

  # Validations
  validates :year, presence: true,
                   numericality: { greater_than: 2020, less_than_or_equal_to: 2100 }
  validates :month, presence: true,
                    numericality: { greater_than: 0, less_than: 13 }
  validates :user_id, uniqueness: { scope: [:year, :month], message: 'この月の締め処理は既に存在します' }
  validates :status, presence: true
  validates :total_work_hours, presence: true,
                               numericality: { greater_than_or_equal_to: 0 }
  validates :total_work_days, presence: true,
                              numericality: { greater_than_or_equal_to: 0 }
  validates :overtime_hours, presence: true,
                             numericality: { greater_than_or_equal_to: 0 }
  validates :closed_at, presence: true, if: :approved_or_locked?
  validates :closed_by_id, presence: true, if: :approved_or_locked?

  # Callbacks
  before_save :set_closed_at, if: :status_changed_to_closed?
  before_save :calculate_totals, if: -> { open? || status_changed_to_closed? }

  # Scopes
  scope :for_year, ->(year) { where(year: year) }
  scope :for_month, ->(year, month) { where(year: year, month: month) }
  scope :for_date, ->(date) { where(year: date.year, month: date.month) }
  scope :for_period, lambda { |start_date, end_date|
    where(
      '(year = ? AND month >= ?) OR (year > ? AND year < ?) OR (year = ? AND month <= ?)',
      start_date.year, start_date.month,
      start_date.year, end_date.year,
      end_date.year, end_date.month
    )
  }
  scope :recent, -> { order(year: :desc, month: :desc) }
  scope :closed_records, -> { where(status: [:closed, :locked]) }
  scope :pending_approvals, -> { where(status: :pending_approval) }

  # Helper methods
  def status_display_name
    {
      'open' => '作業中',
      'pending_approval' => '承認待ち',
      'closed' => '承認済み',
      'locked' => '確定済み',
    }[status]
  end

  def period_display
    "#{year}年#{month}月"
  end

  def period_start_date
    Date.new(year, month, 1)
  end

  def period_end_date
    Date.new(year, month, -1)
  end

  def closed_or_locked?
    closed? || locked?
  end

  def approved_or_locked?
    closed? || locked?
  end

  def can_edit?
    open?
  end

  def all_attendances_approved?
    # 勤怠は承認フローなし（自動生成のため）
    # 月末締めは勤怠データが存在すれば承認可能
    true
  end

  def can_submit_for_approval?
    open? && all_attendances_approved?
  end

  def can_approve?
    pending_approval?
  end

  def can_reject?
    pending_approval?
  end

  def can_lock?
    closed?
  end

  def can_reopen?
    closed? && !locked?
  end

  def overtime_rate_display
    return '0%' if total_work_hours.zero?

    rate = (overtime_hours / total_work_hours * 100).round(1)
    "#{rate}%"
  end

  def average_daily_hours
    return 0 if total_work_days.zero?

    (total_work_hours / total_work_days).round(2)
  end

  def work_hours_display
    "#{total_work_hours}時間"
  end

  def overtime_hours_display
    "#{overtime_hours}時間"
  end

  def period_attendances
    user.attendances.for_month(year, month)
  end

  def summary
    {
      period: period_display,
      total_work_hours: total_work_hours,
      total_work_days: total_work_days,
      overtime_hours: overtime_hours,
      average_daily_hours: average_daily_hours,
      overtime_rate: overtime_rate_display,
      status: status_display_name,
    }
  end

  # Class methods
  def self.create_for_user_and_month(user, year, month)
    return if exists?(user: user, year: year, month: month)

    month_summary = Attendance.monthly_summary(user, year, month)

    create!(
      user: user,
      year: year,
      month: month,
      status: :open,
      total_work_hours: month_summary[:total_hours] || 0,
      total_work_days: month_summary[:total_days] || 0,
      overtime_hours: calculate_overtime_hours(month_summary[:total_hours] || 0)
    )
  end

  def self.close_for_user_and_month(user, year, month, closed_by_user)
    closing = find_by(user: user, year: year, month: month, status: :open)
    return false unless closing&.can_close?

    closing.update!(
      status: :closed,
      closed_by: closed_by_user,
      closed_at: Time.current
    )
    true
  end

  def self.lock_for_user_and_month(user, year, month, locked_by_user)
    closing = find_by(user: user, year: year, month: month, status: :closed)
    return false unless closing&.can_lock?

    closing.update!(
      status: :locked,
      closed_by: locked_by_user,
      closed_at: Time.current
    )
    true
  end

  def self.reopen_for_user_and_month(user, year, month)
    closing = find_by(user: user, year: year, month: month, status: :closed)
    return false unless closing&.can_reopen?

    closing.update!(
      status: :open,
      closed_by: nil,
      closed_at: nil
    )
    true
  end

  def self.monthly_summary_for_users(year, month)
    for_month(year, month).includes(:user).map do |closing|
      {
        user: closing.user,
        summary: closing.summary,
      }
    end
  end

  def self.calculate_overtime_hours(total_hours)
    # 月160時間を超える分を残業とする（週40時間 * 4週間）
    standard_hours = 160
    return 0 if total_hours <= standard_hours

    total_hours - standard_hours
  end

  private

  def status_changed_to_closed?
    status_changed? && (closed? || locked?)
  end

  def set_closed_at
    self.closed_at = Time.current if closed_at.blank?
  end

  def calculate_totals
    month_summary = Attendance.monthly_summary(user, year, month)

    self.total_work_hours = month_summary[:total_hours] || 0
    self.total_work_days = month_summary[:total_days] || 0
    self.overtime_hours = self.class.calculate_overtime_hours(total_work_hours)
  end
end
