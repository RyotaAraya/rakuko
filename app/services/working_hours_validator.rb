# frozen_string_literal: true

# 労働時間制限バリデーター
# 学生の20時間制限（弊社）と40時間制限（総労働）の詳細チェック
class WorkingHoursValidator
  # 制限定数
  WEEKLY_COMPANY_LIMIT = 20.0    # 週20時間（弊社のみ）
  WEEKLY_TOTAL_LIMIT = 40.0      # 週40時間（弊社+掛け持ち）
  DAILY_LIMIT = 8.0              # 日8時間制限
  BREAK_THRESHOLD = 6.0          # 6時間以上で1時間休憩
  BREAK_DURATION = 1.0           # 休憩時間

  class << self
    # 週間シフトの包括的バリデーション
    def validate_weekly_shift(weekly_shift)
      results = {
        valid: true,
        violations: [],
        warnings: [],
        details: {},
      }

      # 日別チェック
      daily_results = validate_daily_schedules(weekly_shift.daily_schedules)
      results[:details][:daily] = daily_results

      if daily_results[:violations].any?
        results[:valid] = false
        results[:violations].concat(daily_results[:violations])
      end

      # 週間チェック
      weekly_results = validate_weekly_totals(weekly_shift)
      results[:details][:weekly] = weekly_results

      if weekly_results[:violations].any?
        results[:valid] = false
        results[:violations].concat(weekly_results[:violations])
      end

      # 警告の追加
      results[:warnings].concat(weekly_results[:warnings])
      results[:warnings].concat(daily_results[:warnings])

      results
    end

    # 日別スケジュールのバリデーション
    def validate_daily_schedules(daily_schedules)
      violations = []
      warnings = []
      details = {}

      daily_schedules.each do |schedule|
        day_result = validate_daily_schedule(schedule)
        details[schedule.schedule_date.to_s] = day_result

        violations.concat(day_result[:violations])
        warnings.concat(day_result[:warnings])
      end

      {
        violations: violations,
        warnings: warnings,
        details: details,
      }
    end

    # 単日スケジュールのバリデーション
    def validate_daily_schedule(schedule)
      violations = []
      warnings = []

      # 基本情報の取得
      company_hours = schedule.company_working_hours
      sidejob_hours = schedule.sidejob_working_hours
      total_hours = company_hours + sidejob_hours
      date_str = schedule.schedule_date.strftime('%m/%d')

      # 時間重複チェック
      violations << "#{date_str}: 弊社と掛け持ちの勤務時間が重複しています" if schedule.has_time_overlap?

      # 日8時間制限チェック
      violations << "#{date_str}: 1日の総労働時間が#{DAILY_LIMIT}時間を超過（#{total_hours.round(1)}時間）" if total_hours > DAILY_LIMIT

      # 弊社単日制限チェック
      if company_hours > DAILY_LIMIT
        violations << "#{date_str}: 弊社の労働時間が#{DAILY_LIMIT}時間を超過（#{company_hours.round(1)}時間）"
      end

      # 長時間労働の警告
      warnings << "#{date_str}: 長時間労働です（#{total_hours.round(1)}時間）。体調管理にご注意ください" if total_hours >= 10

      # 深夜労働の確認
      night_work_warning = check_night_work(schedule)
      warnings << night_work_warning if night_work_warning

      {
        violations: violations,
        warnings: warnings,
        company_hours: company_hours,
        sidejob_hours: sidejob_hours,
        total_hours: total_hours,
        has_overlap: schedule.has_time_overlap?,
      }
    end

    # 週間合計のバリデーション
    def validate_weekly_totals(weekly_shift)
      violations = []
      warnings = []

      company_total = weekly_shift.calculate_company_hours
      sidejob_total = weekly_shift.calculate_sidejob_hours
      grand_total = weekly_shift.calculate_total_hours

      week_title = weekly_shift.week_title

      # 弊社週20時間制限チェック
      if company_total > WEEKLY_COMPANY_LIMIT
        excess = company_total - WEEKLY_COMPANY_LIMIT
        violations << "#{week_title}: 弊社勤務時間が週#{WEEKLY_COMPANY_LIMIT}時間を" \
                      "#{excess.round(1)}時間超過（合計#{company_total.round(1)}時間）"
      end

      # 総労働週40時間制限チェック
      if grand_total > WEEKLY_TOTAL_LIMIT
        excess = grand_total - WEEKLY_TOTAL_LIMIT
        violations << "#{week_title}: 総労働時間が週#{WEEKLY_TOTAL_LIMIT}時間を" \
                      "#{excess.round(1)}時間超過（合計#{grand_total.round(1)}時間）"
      end

      # 制限に近い場合の警告
      if company_total > WEEKLY_COMPANY_LIMIT * 0.9
        warnings << "#{week_title}: 弊社勤務時間が制限に近づいています（#{company_total.round(1)}/#{WEEKLY_COMPANY_LIMIT}時間）"
      end

      if grand_total > WEEKLY_TOTAL_LIMIT * 0.9
        warnings << "#{week_title}: 総労働時間が制限に近づいています（#{grand_total.round(1)}/#{WEEKLY_TOTAL_LIMIT}時間）"
      end

      {
        violations: violations,
        warnings: warnings,
        company_total: company_total,
        sidejob_total: sidejob_total,
        grand_total: grand_total,
        company_limit_usage: (company_total / WEEKLY_COMPANY_LIMIT * 100).round(1),
        total_limit_usage: (grand_total / WEEKLY_TOTAL_LIMIT * 100).round(1),
      }
    end

    # 月次サマリーのバリデーション
    def validate_monthly_summary(monthly_summary)
      violations = []
      warnings = []
      weekly_details = {}

      total_company_hours = 0
      total_sidejob_hours = 0

      monthly_summary.user_weekly_shifts_for_month.each do |weekly_shift|
        weekly_result = validate_weekly_shift(weekly_shift)
        weekly_details[weekly_shift.week.week_number] = weekly_result

        violations.concat(weekly_result[:violations])
        warnings.concat(weekly_result[:warnings])

        total_company_hours += weekly_shift.calculate_company_hours
        total_sidejob_hours += weekly_shift.calculate_sidejob_hours
      end

      # 月間制限チェック（学生の場合）
      monthly_limit = 160 # 月160時間制限（例）
      total_monthly_hours = total_company_hours + total_sidejob_hours

      if total_monthly_hours > monthly_limit
        violations << "月間総労働時間が#{monthly_limit}時間を超過（#{total_monthly_hours.round(1)}時間）"
      end

      {
        valid: violations.empty?,
        violations: violations,
        warnings: warnings,
        weekly_details: weekly_details,
        monthly_totals: {
          company_hours: total_company_hours,
          sidejob_hours: total_sidejob_hours,
          total_hours: total_monthly_hours,
          limit_usage: (total_monthly_hours / monthly_limit * 100).round(1),
        },
      }
    end

    # 複数週にわたる連続勤務チェック
    def check_consecutive_work_days(user, start_date, end_date)
      warnings = []
      consecutive_days = 0
      max_consecutive = 0

      (start_date..end_date).each do |date|
        daily_schedules = user.daily_schedules.joins(:weekly_shift)
                              .where(schedule_date: date)
                              .where('company_actual_hours > 0 OR sidejob_actual_hours > 0')

        if daily_schedules.exists?
          consecutive_days += 1
          max_consecutive = [max_consecutive, consecutive_days].max
        else
          consecutive_days = 0
        end

        warnings << "#{date.strftime('%m/%d')}時点で#{consecutive_days}日連続勤務です。休息をお勧めします" if consecutive_days >= 6
      end

      {
        max_consecutive_days: max_consecutive,
        warnings: warnings,
      }
    end

    private

    # 深夜労働チェック（22:00-05:00）
    def check_night_work(schedule)
      night_periods = []

      # 弊社の深夜労働チェック
      if schedule.has_company_work?
        night_periods << check_time_in_night_hours(
          schedule.company_start_time,
          schedule.company_end_time,
          '弊社'
        )
      end

      # 掛け持ちの深夜労働チェック
      if schedule.has_sidejob_work?
        night_periods << check_time_in_night_hours(
          schedule.sidejob_start_time,
          schedule.sidejob_end_time,
          '掛け持ち'
        )
      end

      night_periods.compact.first
    end

    def check_time_in_night_hours(start_time, end_time, work_type)
      return nil unless start_time && end_time

      Time.zone.parse('22:00')
      Time.zone.parse('05:00')

      # 簡易的な深夜時間帯チェック
      if (start_time.hour >= 22 || start_time.hour < 5) ||
         (end_time.hour >= 22 || end_time.hour < 5)
        "#{work_type}で深夜労働時間帯（22:00-05:00）での勤務があります。労働基準法の深夜手当対象です"
      end
    end
  end
end
