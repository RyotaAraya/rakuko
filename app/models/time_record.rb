# frozen_string_literal: true

class TimeRecord < ApplicationRecord
  belongs_to :user

  # Enums
  enum :record_type, {
    clock_in: 0,
    break_start: 1,
    break_end: 2,
    clock_out: 3,
  }, prefix: true

  # Validations
  validates :date, presence: true
  validates :recorded_at, presence: true
  validates :record_type, presence: true
  validates :break_sequence, presence: true, numericality: { greater_than: 0 }, if: :break_record?
  validate :logical_punch_order
  validate :break_sequence_consistency

  # Scopes
  scope :for_date, ->(date) { where(date: date) }
  scope :for_user_and_date, ->(user, date) { where(user: user, date: date) }
  scope :clock_in_records, -> { where(record_type: :clock_in) }
  scope :clock_out_records, -> { where(record_type: :clock_out) }
  scope :break_records, -> { where(record_type: [:break_start, :break_end]) }
  scope :ordered_by_time, -> { order(:recorded_at) }

  # Helper methods
  def break_record?
    record_type_break_start? || record_type_break_end?
  end

  def work_record?
    record_type_clock_in? || record_type_clock_out?
  end

  def record_type_display_name
    case record_type
    when 'clock_in'
      '出勤'
    when 'break_start'
      "休憩開始(#{break_sequence}回目)"
    when 'break_end'
      "休憩終了(#{break_sequence}回目)"
    when 'clock_out'
      '退勤'
    end
  end

  def time_display
    recorded_at.strftime('%H:%M')
  end

  def datetime_display
    recorded_at.strftime('%Y/%m/%d %H:%M')
  end

  # Class methods
  def self.daily_summary(user, date)
    records = for_user_and_date(user, date).ordered_by_time

    {
      clock_in: records.find(&:record_type_clock_in?),
      clock_out: records.find(&:record_type_clock_out?),
      break_records: records.select(&:break_record?),
      total_records: records.count,
    }
  end

  def self.calculate_work_hours(user, date)
    summary = daily_summary(user, date)
    return 0 unless summary[:clock_in] && summary[:clock_out]

    total_seconds = summary[:clock_out].recorded_at - summary[:clock_in].recorded_at
    break_seconds = calculate_break_seconds(summary[:break_records])

    work_seconds = total_seconds - break_seconds
    (work_seconds / 1.hour.to_f).round(2)
  end

  def self.calculate_break_seconds(break_records)
    break_seconds = 0
    break_pairs = break_records.group_by(&:break_sequence)

    break_pairs.each_value do |records|
      break_start = records.find(&:record_type_break_start?)
      break_end = records.find(&:record_type_break_end?)

      next unless break_start && break_end

      break_seconds += break_end.recorded_at - break_start.recorded_at
    end

    break_seconds
  end

  private

  def logical_punch_order
    return unless date.present? && recorded_at.present?

    same_day_records = user.time_records.for_date(date).where.not(id: id).ordered_by_time
    return if same_day_records.empty?

    # 出勤は最初、退勤は最後でなければならない
    if record_type_clock_in? && same_day_records.any? { |r| r.recorded_at < recorded_at }
      errors.add(:recorded_at, '出勤時刻は他の打刻より前でなければなりません')
    end

    return unless record_type_clock_out? && same_day_records.any? { |r| r.recorded_at > recorded_at }

    errors.add(:recorded_at, '退勤時刻は他の打刻より後でなければなりません')
  end

  def break_sequence_consistency
    return unless break_record? && break_sequence.present?

    same_sequence_records = user.time_records
                                .for_date(date)
                                .where(break_sequence: break_sequence)
                                .where.not(id: id)

    # 同じ休憩回数で重複する種類がないかチェック
    if same_sequence_records.any? { |r| r.record_type == record_type }
      errors.add(:break_sequence, "#{break_sequence}回目の#{record_type_display_name}は既に存在します")
    end

    # 休憩終了より前に休憩開始があるかチェック
    return unless record_type_break_end?

    break_start = same_sequence_records.find(&:record_type_break_start?)
    return unless break_start && break_start.recorded_at >= recorded_at

    errors.add(:recorded_at, '休憩終了時刻は休憩開始時刻より後でなければなりません')
  end
end
