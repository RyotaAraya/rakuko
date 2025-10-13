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

  # 週次労働時間の詳細集計（弊社 + 掛け持ち分離）
  def self.weekly_hours_breakdown(user, start_date)
    end_date = start_date.end_of_week

    # 実績労働時間（承認済みのみ）
    completed_attendances = where(user: user, date: start_date..end_date).approved
    actual_company_hours = completed_attendances.sum(:actual_hours)

    # 掛け持ちバイト時間（shift_requestsから取得）
    # TODO: 掛け持ちバイトの実績記録が実装されたら、そちらから取得
    actual_sidejob_hours = calculate_sidejob_hours(user, start_date, end_date)

    # シフト予定データ（残りの予定時間）
    remaining_shifts = fetch_remaining_shifts(user, start_date, end_date)

    {
      # 実績
      actual_company_hours: actual_company_hours.round(1),
      actual_sidejob_hours: actual_sidejob_hours.round(1),
      actual_total_hours: (actual_company_hours + actual_sidejob_hours).round(1),

      # 予定（残り）
      remaining_company_hours: remaining_shifts[:company].round(1),
      remaining_sidejob_hours: remaining_shifts[:sidejob].round(1),
      remaining_total_hours: (remaining_shifts[:company] + remaining_shifts[:sidejob]).round(1),

      # 予測合計
      predicted_company_hours: (actual_company_hours + remaining_shifts[:company]).round(1),
      predicted_sidejob_hours: (actual_sidejob_hours + remaining_shifts[:sidejob]).round(1),
      predicted_total_hours: (actual_company_hours + actual_sidejob_hours +
                              remaining_shifts[:company] + remaining_shifts[:sidejob]).round(1),

      # 制限値
      company_limit: 20,
      total_limit: 40,

      # 違反フラグ
      company_over_limit: (actual_company_hours + remaining_shifts[:company]) > 20,
      total_over_limit: (actual_company_hours + actual_sidejob_hours +
                        remaining_shifts[:company] + remaining_shifts[:sidejob]) > 40,
    }
  end

  # 制限違反をチェックして警告メッセージを生成
  def self.check_weekly_violations(user, start_date)
    breakdown = weekly_hours_breakdown(user, start_date)
    violations = []

    if breakdown[:company_over_limit]
      violations << {
        type: 'company_hours_exceeded',
        severity: 'error',
        message: "弊社での週20時間制限を超過する予測です（予測: #{breakdown[:predicted_company_hours]}時間）",
        actual: breakdown[:predicted_company_hours],
        limit: 20
      }
    end

    if breakdown[:total_over_limit]
      violations << {
        type: 'total_hours_exceeded',
        severity: 'error',
        message: "週40時間制限を超過する予測です（予測: #{breakdown[:predicted_total_hours]}時間）",
        actual: breakdown[:predicted_total_hours],
        limit: 40
      }
    end

    # 警告レベル（80%以上）
    if breakdown[:predicted_company_hours] >= 16 && !breakdown[:company_over_limit]
      violations << {
        type: 'company_hours_warning',
        severity: 'warning',
        message: "弊社での週20時間制限に近づいています（予測: #{breakdown[:predicted_company_hours]}時間）",
        actual: breakdown[:predicted_company_hours],
        limit: 20
      }
    end

    if breakdown[:predicted_total_hours] >= 32 && !breakdown[:total_over_limit]
      violations << {
        type: 'total_hours_warning',
        severity: 'warning',
        message: "週40時間制限に近づいています（予測: #{breakdown[:predicted_total_hours]}時間）",
        actual: breakdown[:predicted_total_hours],
        limit: 40
      }
    end

    {
      has_violations: violations.any?,
      violations: violations,
      breakdown: breakdown
    }
  end

  private_class_method def self.calculate_sidejob_hours(user, start_date, end_date)
    # TODO: 掛け持ちバイトの実績記録テーブルが実装されたら、そこから取得
    # 現時点ではシフト予定から推測
    0.0
  end

  private_class_method def self.fetch_remaining_shifts(user, start_date, end_date)
    # 今週の残り日数のシフト予定を取得
    today = Date.current
    remaining_dates = (today..end_date).to_a

    # ShiftRequestから該当週のデータを取得
    # TODO: ShiftRequestモデルとの連携実装
    # 現時点では簡易的にゼロを返す

    {
      company: 0.0,
      sidejob: 0.0
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
