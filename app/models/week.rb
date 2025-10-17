# frozen_string_literal: true

class Week < ApplicationRecord
  # Associations
  has_many :weekly_shifts, dependent: :destroy
  has_many :daily_schedules, through: :weekly_shifts
  has_many :users, through: :weekly_shifts

  # Validations
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :year, presence: true
  validates :week_number, presence: true, uniqueness: { scope: :year }
  validates :is_cross_month, inclusion: { in: [true, false] }

  # Validate week dates
  validate :end_date_after_start_date
  validate :week_dates_are_monday_to_sunday
  validate :cross_month_flag_accuracy

  # Scopes
  scope :for_year, ->(year) { where(year: year) }
  scope :for_month, lambda { |year, month|
    where(year: year).joins(:daily_schedules).where(daily_schedules: { schedule_date: Date.new(year, month, 1)..Date.new(year, month, -1) }).distinct
  }
  scope :cross_month, -> { where(is_cross_month: true) }
  scope :single_month, -> { where(is_cross_month: false) }
  scope :by_start_date, -> { order(:start_date) }

  # Class methods
  def self.create_for_date(date)
    # 指定された日付を含む週を作成
    start_of_week = date.beginning_of_week(:monday)
    end_of_week = date.end_of_week(:monday)
    year = start_of_week.year
    week_number = start_of_week.cweek

    # 月跨ぎ判定
    is_cross_month = start_of_week.month != end_of_week.month

    find_or_create_by(
      year: year,
      week_number: week_number
    ) do |week|
      week.start_date = start_of_week
      week.end_date = end_of_week
      week.is_cross_month = is_cross_month
    end
  end

  def self.for_month_range(year, month)
    # 指定月の全ての週を取得（月跨ぎ含む）
    start_date = Date.new(year, month, 1)
    end_date = Date.new(year, month, -1)

    # 月の最初の日から最後の日までの週を全て含める
    first_week_start = start_date.beginning_of_week(:monday)
    last_week_end = end_date.end_of_week(:monday)

    where(start_date: first_week_start..last_week_end).by_start_date
  end

  # Instance methods
  def contains_date?(date)
    date.between?(start_date, end_date)
  end

  def month_for_date(date)
    return nil unless contains_date?(date)

    date.month
  end

  def days_in_month(month)
    # この週のうち、指定された月に含まれる日数
    month_start = Date.new(year, month, 1)
    month_end = Date.new(year, month, -1)

    week_range = start_date..end_date
    month_range = month_start..month_end

    # 重複する期間の日数を計算
    overlap_start = [week_range.begin, month_range.begin].max
    overlap_end = [week_range.end, month_range.end].min

    return 0 if overlap_start > overlap_end

    (overlap_end - overlap_start).to_i + 1
  end

  def primary_month
    # 週の大部分を占める月を返す
    if is_cross_month?
      start_month_days = days_in_month(start_date.month)
      end_month_days = days_in_month(end_date.month)

      start_month_days >= end_month_days ? start_date.month : end_date.month
    else
      start_date.month
    end
  end

  def display_range
    "#{start_date.strftime('%m/%d')}-#{end_date.strftime('%m/%d')}"
  end

  def week_title(target_month = nil)
    if target_month
      "第#{week_number}週 (#{display_range})"
    else
      "#{year}年 第#{week_number}週 (#{display_range})"
    end
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, 'must be after start date') if end_date <= start_date
  end

  def week_dates_are_monday_to_sunday
    return unless start_date && end_date

    errors.add(:start_date, 'must be Monday') unless start_date.monday?
    errors.add(:end_date, 'must be Sunday') unless end_date.sunday?
    errors.add(:end_date, 'must be exactly 6 days after start_date') unless (end_date - start_date).to_i == 6
  end

  def cross_month_flag_accuracy
    return unless start_date && end_date

    actual_cross_month = start_date.month != end_date.month
    return if is_cross_month == actual_cross_month

    errors.add(:is_cross_month, "should be #{actual_cross_month} based on dates")
  end
end
