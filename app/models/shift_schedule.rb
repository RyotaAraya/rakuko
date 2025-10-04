# frozen_string_literal: true

class ShiftSchedule < ApplicationRecord
  belongs_to :shift

  # Delegations
  delegate :user, to: :shift

  # Validations
  validates :date, presence: true
  validates :shift_id, uniqueness: { scope: :date, message: 'この日付のシフトスケジュールは既に存在します' }
  validate :company_time_logical_order
  validate :part_time_logical_order
  validate :date_within_shift_month
  validate :working_hours_limits

  # Scopes
  scope :for_date, ->(date) { where(date: date) }
  scope :for_week, ->(start_date) { where(date: start_date.all_week) }
  scope :with_company_work, -> { where.not(company_start_time: nil, company_end_time: nil) }
  scope :with_part_time_work, -> { where.not(part_time_start_time: nil, part_time_end_time: nil) }

  # Helper methods
  def company_work?
    company_start_time.present? && company_end_time.present?
  end

  def part_time_work?
    part_time_start_time.present? && part_time_end_time.present?
  end

  def company_work_hours
    return 0 unless company_work?

    calculate_work_hours(company_start_time, company_end_time)
  end

  def part_time_work_hours
    return 0 unless part_time_work?

    calculate_work_hours(part_time_start_time, part_time_end_time)
  end

  def total_daily_hours
    company_work_hours + part_time_work_hours
  end

  def company_work_display
    return '休み' unless company_work?

    "#{company_start_time.strftime('%H:%M')} - #{company_end_time.strftime('%H:%M')}"
  end

  def part_time_work_display
    return 'なし' unless part_time_work?

    "#{part_time_start_time.strftime('%H:%M')} - #{part_time_end_time.strftime('%H:%M')}"
  end

  def work_summary
    summary = []
    summary << "自社: #{company_work_display}" if company_work?
    summary << "掛け持ち: #{part_time_work_display}" if part_time_work?
    summary.join(', ')
  end

  private

  def calculate_work_hours(start_time, end_time)
    return 0 if start_time.nil? || end_time.nil?

    # 時刻を秒に変換して差を計算
    seconds_diff = end_time.seconds_since_midnight - start_time.seconds_since_midnight

    # 日を跨ぐ場合の処理
    seconds_diff += 24.hours if seconds_diff.negative?

    # 時間に変換
    (seconds_diff / 1.hour.to_f).round(2)
  end

  def company_time_logical_order
    return unless company_start_time.present? && company_end_time.present?
    return if company_start_time < company_end_time

    errors.add(:company_end_time, '終了時刻は開始時刻より後に設定してください')
  end

  def part_time_logical_order
    return unless part_time_start_time.present? && part_time_end_time.present?
    return if part_time_start_time < part_time_end_time

    errors.add(:part_time_end_time, '終了時刻は開始時刻より後に設定してください')
  end

  def date_within_shift_month
    return unless date.present? && shift.present?

    shift_start = Date.new(shift.year, shift.month, 1)
    shift_end = shift_start.end_of_month

    return if date.between?(shift_start, shift_end)

    errors.add(:date, "日付は#{shift.display_period}の範囲内で設定してください")
  end

  def working_hours_limits
    # 学生の週20時間制限チェック（自社分のみ）
    return unless company_work?

    errors.add(:company_end_time, '1日の労働時間は8時間以内にしてください') if company_work_hours > 8

    # 掛け持ち含む総労働時間の制限（40時間/週）
    return unless total_daily_hours > 12

    errors.add(:base, '1日の総労働時間（掛け持ち含む）は12時間以内にしてください')
  end
end
