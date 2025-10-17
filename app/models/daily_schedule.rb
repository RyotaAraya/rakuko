# frozen_string_literal: true

class DailySchedule < ApplicationRecord
  # Associations
  belongs_to :weekly_shift
  has_one :user, through: :weekly_shift
  has_one :week, through: :weekly_shift

  # Validations
  validates :schedule_date, presence: true
  validates :weekly_shift_id, uniqueness: { scope: :schedule_date }

  # Time validations
  validate :company_time_consistency
  validate :sidejob_time_consistency
  validate :times_within_reasonable_range

  # Callbacks
  before_save :calculate_actual_hours

  # Scopes
  scope :for_date, ->(date) { where(schedule_date: date) }
  scope :for_week, ->(week) { joins(:weekly_shift).where(weekly_shift: { week: week }) }
  scope :for_month, ->(year, month) { where(schedule_date: Date.new(year, month, 1)..Date.new(year, month, -1)) }
  scope :with_company_work, -> { where.not(company_start_time: nil, company_end_time: nil) }
  scope :with_sidejob_work, -> { where.not(sidejob_start_time: nil, sidejob_end_time: nil) }
  scope :by_date, -> { order(:schedule_date) }

  # Instance methods
  def has_company_work?
    company_start_time.present? && company_end_time.present?
  end

  def has_sidejob_work?
    sidejob_start_time.present? && sidejob_end_time.present?
  end

  def has_working_hours?
    has_company_work? || has_sidejob_work?
  end

  def company_working_hours
    return 0 unless has_company_work?

    calculate_working_hours(company_start_time, company_end_time)
  end

  def sidejob_working_hours
    return 0 unless has_sidejob_work?

    calculate_working_hours(sidejob_start_time, sidejob_end_time)
  end

  def total_hours
    (company_actual_hours || 0) + (sidejob_actual_hours || 0)
  end

  def has_time_overlap?
    return false unless has_company_work? && has_sidejob_work?

    company_range = time_range(company_start_time, company_end_time)
    sidejob_range = time_range(sidejob_start_time, sidejob_end_time)

    ranges_overlap?(company_range, sidejob_range)
  end

  def day_name
    schedule_date.strftime('%a')
  end

  def formatted_date
    schedule_date.strftime('%m/%d')
  end

  def date_with_day
    "#{formatted_date}(#{day_name})"
  end

  def working_status
    if has_company_work? && has_sidejob_work?
      'both'
    elsif has_company_work?
      'company'
    elsif has_sidejob_work?
      'sidejob'
    else
      'none'
    end
  end

  def time_summary
    parts = []
    parts << "弊社: #{format_time_range(company_start_time, company_end_time)}" if has_company_work?
    parts << "掛持: #{format_time_range(sidejob_start_time, sidejob_end_time)}" if has_sidejob_work?
    parts.empty? ? '休み' : parts.join(', ')
  end

  # Clear methods
  def clear_company_times!
    self.company_start_time = nil
    self.company_end_time = nil
    self.company_actual_hours = 0
  end

  def clear_sidejob_times!
    self.sidejob_start_time = nil
    self.sidejob_end_time = nil
    self.sidejob_actual_hours = 0
  end

  def clear_all_times!
    clear_company_times!
    clear_sidejob_times!
  end

  # Bulk update methods
  def update_company_times(start_time, end_time)
    self.company_start_time = start_time
    self.company_end_time = end_time
    calculate_actual_hours
  end

  def update_sidejob_times(start_time, end_time)
    self.sidejob_start_time = start_time
    self.sidejob_end_time = end_time
    calculate_actual_hours
  end

  private

  def calculate_working_hours(start_time, end_time)
    return 0 if start_time.blank? || end_time.blank?

    # 時間を秒に変換して計算
    start_seconds = time_to_seconds(start_time)
    end_seconds = time_to_seconds(end_time)

    # 日をまたぐ場合の処理
    end_seconds += 24 * 3600 if end_seconds < start_seconds

    working_seconds = end_seconds - start_seconds
    working_hours = working_seconds / 3600.0

    # 6時間以上の場合は1時間の休憩を差し引く
    working_hours >= 6 ? working_hours - 1 : working_hours
  end

  def time_to_seconds(time)
    return 0 if time.blank?

    (time.hour * 3600) + (time.min * 60) + time.sec
  end

  def time_range(start_time, end_time)
    return nil if start_time.blank? || end_time.blank?

    start_seconds = time_to_seconds(start_time)
    end_seconds = time_to_seconds(end_time)

    # 日をまたぐ場合の処理
    end_seconds += 24 * 3600 if end_seconds < start_seconds

    start_seconds..end_seconds
  end

  def ranges_overlap?(range1, range2)
    return false if range1.nil? || range2.nil?

    range1.cover?(range2.begin) || range2.cover?(range1.begin)
  end

  def format_time_range(start_time, end_time)
    return '' if start_time.blank? || end_time.blank?

    "#{start_time.strftime('%H:%M')}-#{end_time.strftime('%H:%M')}"
  end

  def calculate_actual_hours
    self.company_actual_hours = company_working_hours
    self.sidejob_actual_hours = sidejob_working_hours
  end

  # Validations
  def company_time_consistency
    return unless company_start_time.present? || company_end_time.present?

    if company_start_time.blank?
      errors.add(:company_start_time, 'は終了時間が設定されている場合必須です')
    elsif company_end_time.blank?
      errors.add(:company_end_time, 'は開始時間が設定されている場合必須です')
    elsif company_start_time >= company_end_time
      # 日をまたぐ場合は許可（深夜勤務等）
      # errors.add(:company_end_time, 'は開始時間より後に設定してください')
    end
  end

  def sidejob_time_consistency
    return unless sidejob_start_time.present? || sidejob_end_time.present?

    if sidejob_start_time.blank?
      errors.add(:sidejob_start_time, 'は終了時間が設定されている場合必須です')
    elsif sidejob_end_time.blank?
      errors.add(:sidejob_end_time, 'は開始時間が設定されている場合必須です')
    elsif sidejob_start_time >= sidejob_end_time
      # 日をまたぐ場合は許可（深夜勤務等）
      # errors.add(:sidejob_end_time, 'は開始時間より後に設定してください')
    end
  end

  def times_within_reasonable_range
    # 実労働時間が24時間を超えないことをチェック
    errors.add(:company_end_time, '弊社勤務時間が24時間を超えています') if company_working_hours > 24

    return unless sidejob_working_hours > 24

    errors.add(:sidejob_end_time, '掛け持ち勤務時間が24時間を超えています')
  end
end
