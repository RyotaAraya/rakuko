# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_action :set_target_date

  def shift_requests
    authorize @user, :show_shift_requests?

    # 利用可能な月のリストを取得
    @available_months = @user.available_months_for_shift

    # 月次サマリーとシフトデータを作成または取得
    @monthly_summary = WeekManagementService.create_monthly_summary_with_shifts(
      @user,
      @target_year,
      @target_month
    )

    # シフトデータを準備
    @weeks_data = build_weeks_data_for_vue
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_target_date
    @target_year = params[:year]&.to_i || Date.current.year
    @target_month = params[:month]&.to_i || Date.current.month
    @target_date = Date.new(@target_year, @target_month, 1)
  end

  def build_weeks_data_for_vue
    weeks = WeekManagementService.generate_weeks_for_month(@target_year, @target_month)

    weeks.map.with_index(1) do |week, index|
      {
        id: week.id,
        title: "第#{index}週 #{week.display_range}",
        isCrossMonth: week.is_cross_month?,
        daysInMonth: week.days_in_month(@target_month),
        days: build_week_days(week),
        shifts: build_week_shifts_data(week),
      }
    end
  end

  def build_week_days(week)
    (week.start_date..week.end_date).map do |date|
      {
        key: date.strftime('%a').downcase,
        label: "#{%w[日 月 火 水 木 金 土][date.wday]} #{date.strftime('%m/%d')}",
        inTargetMonth: date.month == @target_month,
        date: date.iso8601,
      }
    end
  end

  def build_week_shifts_data(week)
    weekly_shift = @user.weekly_shifts.find_by(week: week)
    weekly_shift ? build_existing_shifts_data(weekly_shift) : build_empty_shifts_data
  end

  def build_existing_shifts_data(weekly_shift)
    company_start = {}
    company_end = {}
    sidejob_start = {}
    sidejob_end = {}

    weekly_shift.daily_schedules.each do |schedule|
      day_key = schedule.schedule_date.strftime('%a').downcase
      company_start[day_key] = schedule.company_start_time || ''
      company_end[day_key] = schedule.company_end_time || ''
      sidejob_start[day_key] = schedule.sidejob_start_time || ''
      sidejob_end[day_key] = schedule.sidejob_end_time || ''
    end

    { company: { start: company_start, end: company_end },
      sidejob: { start: sidejob_start, end: sidejob_end } }
  end

  def build_empty_shifts_data
    empty_times = %w[sun mon tue wed thu fri sat].index_with { |_day| '' }
    { company: { start: empty_times.dup, end: empty_times.dup },
      sidejob: { start: empty_times.dup, end: empty_times.dup } }
  end
end
