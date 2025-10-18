# frozen_string_literal: true

# 月跨ぎ週管理サービス
# 複雑な週の生成、月跨ぎ判定、週間シフト作成を統括管理
class WeekManagementService
  class << self
    # 指定月の全ての週を生成（月跨ぎ週含む）
    def generate_weeks_for_month(year, month)
      start_date = Date.new(year, month, 1)
      end_date = Date.new(year, month, -1)

      # 月の最初の週の開始日（月曜日）を取得
      first_week_start = start_date.beginning_of_week(:monday)
      # 月の最後の週の終了日（日曜日）を取得
      last_week_end = end_date.end_of_week(:monday)

      weeks = []
      current_date = first_week_start

      while current_date <= last_week_end
        week = Week.create_for_date(current_date)
        weeks << week
        current_date += 7.days
      end

      weeks
    end

    # ユーザーの指定月分の月次サマリーとシフトを作成
    def create_monthly_summary_with_shifts(user, year, month)
      # 月次サマリーを作成
      monthly_summary = MonthlySummary.create_with_weekly_shifts(user, year, month)

      # 該当月の週を取得
      weeks = generate_weeks_for_month(year, month)

      # 各週に対してWeeklyShiftを作成（未作成の場合のみ）
      weeks.each do |week|
        user.weekly_shifts.find_or_create_by(week: week) do |ws|
          ws.submission_year = year
          ws.submission_month = month
        end
      end

      monthly_summary
    end

    # 月跨ぎ週の分析
    def analyze_cross_month_weeks(year, month)
      weeks = generate_weeks_for_month(year, month)
      cross_month_weeks = weeks.select(&:is_cross_month?)

      {
        total_weeks: weeks.count,
        cross_month_weeks: cross_month_weeks.count,
        cross_month_details: cross_month_weeks.map do |week|
          {
            week_number: week.week_number,
            start_date: week.start_date,
            end_date: week.end_date,
            primary_month: week.primary_month,
            days_in_target_month: week.days_in_month(month),
          }
        end,
      }
    end

    # 特定の日付が属する週の取得または作成
    def find_or_create_week_for_date(date)
      Week.create_for_date(date)
    end

    # 週のタイトル生成（月跨ぎ考慮）
    def generate_week_titles_for_month(year, month)
      weeks = generate_weeks_for_month(year, month)

      weeks.map.with_index(1) do |week, index|
        if week.is_cross_month?
          days_in_month = week.days_in_month(month)
          cross_month_info = "(#{days_in_month}日間)"
          "第#{index}週 #{week.display_range} #{cross_month_info}"
        else
          "第#{index}週 #{week.display_range}"
        end
      end
    end

    # 月跨ぎ週の提出先月判定
    def determine_submission_month_for_week(week)
      if week.is_cross_month?
        # より多くの日数が含まれる月を提出先とする
        start_month_days = week.days_in_month(week.start_date.month)
        end_month_days = week.days_in_month(week.end_date.month)

        if start_month_days >= end_month_days
          {
            month: week.start_date.month,
            year: week.start_date.year,
            days_count: start_month_days,
          }
        else
          {
            month: week.end_date.month,
            year: week.end_date.year,
            days_count: end_month_days,
          }
        end
      else
        {
          month: week.start_date.month,
          year: week.start_date.year,
          days_count: 7,
        }
      end
    end

    # 複数月のシフト一括作成
    def bulk_create_monthly_shifts(user, start_year, start_month, end_year, end_month)
      results = []
      current_year = start_year
      current_month = start_month

      while current_year <= end_year
        while current_month <= 12
          break if current_year == end_year && current_month > end_month

          summary = create_monthly_summary_with_shifts(user, current_year, current_month)
          results << {
            year: current_year,
            month: current_month,
            summary: summary,
            weeks_count: summary.weeks_for_month.count,
          }

          current_month += 1
        end

        current_year += 1
        current_month = 1
      end

      results
    end

    # 週間労働時間集計（月跨ぎ考慮）
    def calculate_weekly_hours_for_month(user, year, month)
      weekly_shifts = user.weekly_shifts.for_month(year, month).includes(:daily_schedules, :week)

      weekly_shifts.map do |weekly_shift|
        {
          week_number: weekly_shift.week.week_number,
          week_title: weekly_shift.week_title,
          company_hours: weekly_shift.calculate_company_hours,
          sidejob_hours: weekly_shift.calculate_sidejob_hours,
          total_hours: weekly_shift.calculate_total_hours,
          is_cross_month: weekly_shift.week.is_cross_month?,
          days_in_month: weekly_shift.week.days_in_month(month),
          has_violations: weekly_shift.has_violations?,
        }
      end
    end

    # シフト提出可能週の判定
    def submittable_weeks_for_month(_user, year, month)
      weeks = generate_weeks_for_month(year, month)
      current_date = Date.current

      weeks.select do |week|
        # 提出締切の判定ロジック
        # 例：週の終了日から3日以内は提出可能
        deadline = week.end_date + 3.days
        current_date <= deadline
      end
    end

    # デバッグ用：月の週構成確認
    def debug_month_weeks(year, month)
      Rails.logger.debug { "=== #{year}年#{month}月 週構成分析 ===" }

      weeks = generate_weeks_for_month(year, month)
      analysis = analyze_cross_month_weeks(year, month)

      Rails.logger.debug { "合計週数: #{analysis[:total_weeks]}" }
      Rails.logger.debug { "月跨ぎ週数: #{analysis[:cross_month_weeks]}" }
      Rails.logger.debug ''

      weeks.each.with_index(1) do |week, index|
        Rails.logger.debug { "第#{index}週: #{week.display_range}" }
        Rails.logger.debug { "  - 週番号: #{week.week_number}" }
        Rails.logger.debug { "  - 月跨ぎ: #{week.is_cross_month? ? 'あり' : 'なし'}" }
        Rails.logger.debug { "  - #{month}月内日数: #{week.days_in_month(month)}日" }

        if week.is_cross_month?
          submission = determine_submission_month_for_week(week)
          Rails.logger.debug { "  - 提出先: #{submission[:year]}年#{submission[:month]}月 (#{submission[:days_count]}日間)" }
        end

        Rails.logger.debug ''
      end
    end
  end
end
