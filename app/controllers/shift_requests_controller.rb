# frozen_string_literal: true

class ShiftRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_target_date, only: [:new, :create, :update]

  def new
    # 利用可能な月のリストを取得
    @available_months = current_user.available_months_for_shift
    @can_edit = current_user.can_edit_shift_for_month?(@target_year, @target_month)
    @past_deadline = current_user.past_deadline_for_month?(@target_year, @target_month)

    # 月次サマリーとシフトデータを作成または取得
    @monthly_summary = WeekManagementService.create_monthly_summary_with_shifts(
      current_user,
      @target_year,
      @target_month
    )

    # Vue.js用の週データを準備
    @weeks_data = build_weeks_data_for_vue
    @initial_shift_data = build_initial_shift_data

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: { weeks: @weeks_data, initialData: @initial_shift_data } }
    end
  end

  def create
    # 週間シフトデータの保存または更新
    result = save_weekly_shifts(params[:weeks_data])

    if result[:success]
      if params[:submit_type] == 'draft'
        render json: { success: true, message: '下書きを保存しました' }
      else
        # 最終提出の場合
        submit_result = submit_monthly_shifts
        if submit_result[:success]
          render json: { success: true, message: 'シフトを提出しました' }
        else
          render json: { success: false, errors: submit_result[:errors] }
        end
      end
    else
      render json: { success: false, errors: result[:errors] }
    end
  end

  def update
    # 週間シフトの個別更新
    weekly_shift = current_user.weekly_shifts.find_by(id: params[:weekly_shift_id])

    if weekly_shift&.update(weekly_shift_params)
      render json: { success: true, weekly_shift: weekly_shift }
    else
      render json: { success: false, errors: weekly_shift&.errors || ['週間シフトが見つかりません'] }
    end
  end

  private

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
    weekly_shift = current_user.weekly_shifts.find_by(week: week)

    if weekly_shift
      # 既存データから復元
      company_start = {}
      company_end = {}
      sidejob_start = {}
      sidejob_end = {}

      weekly_shift.daily_schedules.each do |schedule|
        day_key = schedule.schedule_date.strftime('%a').downcase
        company_start[day_key] = schedule.company_start_time&.strftime('%H:%M') || ''
        company_end[day_key] = schedule.company_end_time&.strftime('%H:%M') || ''
        sidejob_start[day_key] = schedule.sidejob_start_time&.strftime('%H:%M') || ''
        sidejob_end[day_key] = schedule.sidejob_end_time&.strftime('%H:%M') || ''
      end

      {
        company: { start: company_start, end: company_end },
        sidejob: { start: sidejob_start, end: sidejob_end },
      }
    else
      # 空のデータ
      empty_times = %w[sun mon tue wed thu fri sat].index_with { |_day| '' }
      {
        company: { start: empty_times.dup, end: empty_times.dup },
        sidejob: { start: empty_times.dup, end: empty_times.dup },
      }
    end
  end

  def build_initial_shift_data
    {
      targetYear: @target_year,
      targetMonth: @target_month,
      monthlySum: @monthly_summary.as_json(
        include: {
          user_weekly_shifts_for_month: {
            include: {
              daily_schedules: {},
              week: {},
            },
          },
        }
      ),
    }
  end

  def save_weekly_shifts(weeks_data)
    errors = []
    success_count = 0

    # JSON文字列をパース
    parsed_weeks_data = weeks_data.is_a?(String) ? JSON.parse(weeks_data) : weeks_data

    ActiveRecord::Base.transaction do
      parsed_weeks_data.each do |week_data|
        week = Week.find(week_data['id'])
        weekly_shift = current_user.weekly_shifts.find_or_create_by(week: week) do |ws|
          ws.submission_year = @target_year
          ws.submission_month = @target_month
        end

        # 日別スケジュールの更新
        week_data['days'].each do |day_data|
          date = Date.parse(day_data['date'])
          daily_schedule = weekly_shift.daily_schedules.find_or_create_by(schedule_date: date)

          # 時間データの更新
          shifts = week_data['shifts']
          day_key = day_data['key']

          daily_schedule.update!(
            company_start_time: parse_time(shifts['company']['start'][day_key]),
            company_end_time: parse_time(shifts['company']['end'][day_key]),
            sidejob_start_time: parse_time(shifts['sidejob']['start'][day_key]),
            sidejob_end_time: parse_time(shifts['sidejob']['end'][day_key])
          )
        end

        # 制限チェック
        errors.concat(weekly_shift.violation_list) unless weekly_shift.validate_working_hours

        success_count += 1
      end

      raise ActiveRecord::Rollback if errors.any? && params[:submit_type] != 'draft'
    end

    {
      success: errors.empty? || params[:submit_type] == 'draft',
      errors: errors,
      saved_weeks: success_count,
    }
  end

  def submit_monthly_shifts
    @monthly_summary.reload

    if @monthly_summary.can_submit?
      @monthly_summary.submit!
      { success: true }
    else
      { success: false, errors: ['制限違反があるため提出できません'] }
    end
  end

  def parse_time(time_string)
    return nil if time_string.blank?

    Time.zone.parse(time_string)
  rescue ArgumentError
    nil
  end

  def weekly_shift_params
    params.require(:weekly_shift).permit(:status, :violation_warnings)
  end
end
