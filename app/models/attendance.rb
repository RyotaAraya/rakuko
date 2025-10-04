# frozen_string_literal: true

class Attendance < ApplicationRecord
  belongs_to :user
  has_many :approvals, as: :approvable, dependent: :destroy

  # Enums
  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2,
  }

  # Validations
  validates :date, presence: true
  validates :user_id, uniqueness: { scope: :date, message: 'この日付の勤怠記録は既に存在します' }
  validates :actual_hours, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_break_time, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true

  # Scopes
  scope :for_date, ->(date) { where(date: date) }
  scope :for_month, ->(year, month) { where(date: Date.new(year, month, 1)..Date.new(year, month, -1)) }
  scope :for_week, ->(start_date) { where(date: start_date.all_week) }
  scope :auto_generated, -> { where(is_auto_generated: true) }
  scope :manual_entry, -> { where(is_auto_generated: false) }
  scope :pending_approval, -> { where(status: :pending) }
  scope :approved, -> { where(status: :approved) }

  # Callbacks
  before_save :calculate_break_time_from_records, if: :is_auto_generated?

  # Helper methods
  def work_hours_display
    "#{actual_hours}時間"
  end

  def break_time_display
    hours = total_break_time / 60
    minutes = total_break_time % 60

    if hours.positive?
      "#{hours}時間#{minutes}分"
    else
      "#{minutes}分"
    end
  end

  def status_display_name
    {
      'pending' => '承認待ち',
      'approved' => '承認済み',
      'rejected' => '却下',
    }[status]
  end

  def generation_type_display
    is_auto_generated? ? '自動生成' : '手動入力'
  end

  def over_work_hours?
    actual_hours > 8
  end

  def insufficient_break?
    return false unless actual_hours > 6

    required_break = (((actual_hours - 6) / 6).floor * 60) + 60 # 6時間超えで1時間、以降6時間毎に追加
    total_break_time < required_break
  end

  def violations?
    over_work_hours? || insufficient_break?
  end

  def violation_messages
    messages = []
    messages << '1日8時間の労働時間を超過しています' if over_work_hours?
    messages << '必要な休憩時間が不足しています' if insufficient_break?
    messages
  end

  # Class methods
  def self.generate_from_time_records(user, date)
    work_hours = TimeRecord.calculate_work_hours(user, date)
    break_seconds = TimeRecord.calculate_break_seconds(
      TimeRecord.for_user_and_date(user, date).select(&:break_record?)
    )
    break_minutes = (break_seconds / 60).round

    find_or_initialize_by(user: user, date: date, is_auto_generated: true).tap do |attendance|
      attendance.actual_hours = work_hours
      attendance.total_break_time = break_minutes
      attendance.status = :pending
    end
  end

  def self.weekly_summary(user, start_date)
    week_attendances = for_week(start_date).where(user: user).approved
    {
      total_hours: week_attendances.sum(:actual_hours),
      total_days: week_attendances.count,
      avg_hours: week_attendances.average(:actual_hours)&.round(2) || 0,
    }
  end

  def self.monthly_summary(user, year, month)
    month_attendances = for_month(year, month).where(user: user).approved
    {
      total_hours: month_attendances.sum(:actual_hours),
      total_days: month_attendances.count,
      avg_hours: month_attendances.average(:actual_hours)&.round(2) || 0,
      pending_count: for_month(year, month).where(user: user).pending.count,
    }
  end

  private

  def calculate_break_time_from_records
    return unless is_auto_generated?

    break_records = user.time_records.for_date(date).select(&:break_record?)
    break_seconds = TimeRecord.calculate_break_seconds(break_records)
    self.total_break_time = (break_seconds / 60).round
  end
end
