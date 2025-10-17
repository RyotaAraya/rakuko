# frozen_string_literal: true

class MonthlySummary < ApplicationRecord
  include AASM

  # Associations
  belongs_to :user
  has_many :weekly_shifts, lambda { |summary|
    where(submission_year: summary.target_year, submission_month: summary.target_month)
  }, through: :user
  has_many :daily_schedules, through: :weekly_shifts

  # Enums
  enum :status, { draft: 0, submitted: 1, approved: 2, rejected: 3 }

  # Validations
  validates :target_year, presence: true
  validates :target_month, presence: true, inclusion: { in: 1..12 }
  validates :user_id, uniqueness: { scope: [:target_year, :target_month] }

  # Callbacks
  before_save :calculate_totals

  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :for_month, ->(year, month) { where(target_year: year, target_month: month) }
  scope :recent, -> { order(target_year: :desc, target_month: :desc) }
  scope :by_month, -> { order(:target_year, :target_month) }

  # AASM state management
  aasm column: :status, enum: true do
    state :draft, initial: true
    state :submitted
    state :approved
    state :rejected

    event :submit do
      transitions from: :draft, to: :submitted
      after do
        self.submitted_at = Time.current
      end
    end

    event :approve do
      transitions from: :submitted, to: :approved
    end

    event :reject do
      transitions from: :submitted, to: :rejected
    end

    event :revert_to_draft do
      transitions from: [:submitted, :rejected], to: :draft
      after do
        self.submitted_at = nil
      end
    end
  end

  # Instance methods
  def month_name
    "#{target_year}年#{target_month}月"
  end

  def weeks_for_month
    Week.for_month_range(target_year, target_month)
  end

  def user_weekly_shifts_for_month
    user.weekly_shifts.for_month(target_year, target_month).includes(:week, :daily_schedules)
  end

  def calculate_company_hours
    user_weekly_shifts_for_month.sum(&:calculate_company_hours)
  end

  def calculate_sidejob_hours
    user_weekly_shifts_for_month.sum(&:calculate_sidejob_hours)
  end

  def calculate_total_hours
    calculate_company_hours + calculate_sidejob_hours
  end

  def has_violations?
    user_weekly_shifts_for_month.any?(&:has_violations?)
  end

  def violation_summary
    violations = []
    user_weekly_shifts_for_month.each do |weekly_shift|
      next unless weekly_shift.has_violations?

      violations << "#{weekly_shift.week_title}: #{weekly_shift.violation_list.join(', ')}"
    end
    violations
  end

  def can_submit?
    draft? && user_weekly_shifts_for_month.any? && !has_violations?
  end

  def working_days_count
    daily_schedules.joins(:weekly_shift)
                   .where(weekly_shift: { submission_year: target_year, submission_month: target_month })
                   .select(&:has_working_hours?)
                   .count
  end

  def average_daily_hours
    working_days = working_days_count
    return 0 if working_days.zero?

    total_hours / working_days
  end

  def is_over_monthly_limit?
    # 学生の月間労働時間制限チェック（例：160時間）
    total_hours > 160
  end

  def completion_percentage
    total_weeks = weeks_for_month.count
    completed_weeks = user_weekly_shifts_for_month.count

    return 0 if total_weeks.zero?

    (completed_weeks.to_f / total_weeks * 100).round(1)
  end

  # Class methods
  def self.create_with_weekly_shifts(user, year, month)
    summary = find_or_create_by(
      user: user,
      target_year: year,
      target_month: month
    )

    # 該当月の週を取得してWeeklyShiftを作成
    weeks = Week.for_month_range(year, month)
    weeks.each do |week|
      next if user.weekly_shifts.exists?(week: week)

      WeeklyShift.create_with_daily_schedules(user, week, year, month)
    end

    summary
  end

  def self.for_current_month(user)
    current_date = Date.current
    for_month(current_date.year, current_date.month).for_user(user).first
  end

  def self.create_for_current_month(user)
    current_date = Date.current
    create_with_weekly_shifts(user, current_date.year, current_date.month)
  end

  private

  def calculate_totals
    self.total_company_hours = calculate_company_hours
    self.total_sidejob_hours = calculate_sidejob_hours
    self.total_hours = total_company_hours + total_sidejob_hours
  end
end
