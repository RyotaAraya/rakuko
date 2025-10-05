# frozen_string_literal: true

class WeeklyShift < ApplicationRecord
  include AASM

  # Associations
  belongs_to :user
  belongs_to :week
  has_many :daily_schedules, dependent: :destroy

  # Enums
  enum :status, { draft: 0, tentative: 1, confirmed: 2, approved: 3 }

  # Validations
  validates :submission_month, presence: true, inclusion: { in: 1..12 }
  validates :submission_year, presence: true
  validates :user_id, uniqueness: { scope: :week_id }

  # Callbacks
  before_validation :set_submission_date_from_week, if: -> { week.present? && (submission_month.blank? || submission_year.blank?) }
  after_create :create_daily_schedules

  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :for_week, ->(week) { where(week: week) }
  scope :for_month, ->(year, month) { where(submission_year: year, submission_month: month) }
  scope :with_violations, -> { where.not(violation_warnings: [nil, '']) }
  scope :by_submission_date, -> { order(:submission_year, :submission_month) }
  scope :recent, -> { order(created_at: :desc) }

  # AASM state management
  aasm column: :status, enum: true do
    state :draft, initial: true
    state :tentative
    state :confirmed
    state :approved

    event :submit do
      transitions from: :draft, to: :tentative
      after do
        self.submitted_at = Time.current
        validate_working_hours
      end
    end

    event :confirm do
      transitions from: :tentative, to: :confirmed
    end

    event :approve do
      transitions from: :confirmed, to: :approved
    end

    event :reject do
      transitions from: [:tentative, :confirmed], to: :draft
      after do
        self.submitted_at = nil
      end
    end
  end

  # Instance methods
  def calculate_total_hours
    daily_schedules.sum(&:total_hours)
  end

  def calculate_company_hours
    daily_schedules.sum(&:company_actual_hours)
  end

  def calculate_sidejob_hours
    daily_schedules.sum(&:sidejob_actual_hours)
  end

  def validate_working_hours
    violations = []

    # 週20時間制限チェック（弊社のみ）
    company_hours = calculate_company_hours
    if company_hours > 20
      violations << "弊社勤務時間が週20時間を超過しています（#{company_hours}時間）"
    end

    # 週40時間制限チェック（弊社+掛け持ち）
    total_hours = calculate_total_hours
    if total_hours > 40
      violations << "総勤務時間が週40時間を超過しています（#{total_hours}時間）"
    end

    # 日別の重複チェック
    daily_schedules.each do |schedule|
      if schedule.has_time_overlap?
        violations << "#{schedule.schedule_date.strftime('%m/%d')}に弊社と掛け持ちの時間重複があります"
      end
    end

    self.violation_warnings = violations.empty? ? nil : violations.join("\n")
    violations.empty?
  end

  def has_violations?
    violation_warnings.present?
  end

  def violation_list
    return [] if violation_warnings.blank?

    violation_warnings.split("\n")
  end

  def can_submit?
    draft? && daily_schedules.any?(&:has_working_hours?)
  end

  def belongs_to_month?(year, month)
    submission_year == year && submission_month == month
  end

  def week_title
    week.week_title(submission_month)
  end

  def submission_period
    "#{submission_year}年#{submission_month}月提出分"
  end

  # Class methods
  def self.create_with_daily_schedules(user, week, submission_year, submission_month)
    weekly_shift = create!(
      user: user,
      week: week,
      submission_year: submission_year,
      submission_month: submission_month
    )

    # DailyScheduleはafter_createコールバックで自動作成される

    weekly_shift
  end

  private

  def set_submission_date_from_week
    return unless week

    # 週の主要月を提出対象月とする
    primary_month = week.primary_month
    primary_year = week.start_date.month == primary_month ? week.start_date.year : week.end_date.year

    self.submission_month = primary_month
    self.submission_year = primary_year
  end

  def create_daily_schedules
    return if daily_schedules.exists?

    # 週の各日に対してDailyScheduleを作成
    (week.start_date..week.end_date).each do |date|
      daily_schedules.create!(schedule_date: date)
    end
  end
end