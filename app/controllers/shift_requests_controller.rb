# frozen_string_literal: true

class ShiftRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_target_date, only: [:new, :create, :update]

  def new
    authorize :shift_request, :new?
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
    authorize :shift_request, :create?

    # 編集権限チェック
    unless @can_edit
      render json: { success: false, errors: ['この月のシフトは編集できません（過去月または契約期間外）'] }, status: :forbidden
      return
    end

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
    authorize :shift_request, :update?

    # 編集権限チェック
    unless @can_edit
      render json: { success: false, errors: ['この月のシフトは編集できません（過去月または契約期間外）'] }, status: :forbidden
      return
    end

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
    # デフォルトは今月（当月も編集可能）
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
    parsed_weeks_data = parse_weeks_data(weeks_data)

    ActiveRecord::Base.transaction do
      parsed_weeks_data.each do |week_data|
        weekly_shift = find_or_create_weekly_shift(week_data)
        update_daily_schedules(weekly_shift, week_data)
        errors.concat(weekly_shift.violation_list) unless weekly_shift.validate_working_hours
        success_count += 1
      end

      raise ActiveRecord::Rollback if errors.any? && params[:submit_type] != 'draft'
    end

    build_save_result(errors, success_count)
  end

  def submit_monthly_shifts
    @monthly_summary = find_or_create_monthly_summary
    @monthly_summary.reload
    @monthly_summary.back_to_draft! if @monthly_summary.submitted?

    if @monthly_summary.can_submit?
      @monthly_summary.submit!
      { success: true }
    else
      { success: false, errors: build_submission_errors }
    end
  end

  def find_or_create_monthly_summary
    MonthlySummary.find_or_create_by(
      user: current_user,
      target_year: @target_year,
      target_month: @target_month
    )
  end

  def build_submission_errors
    violation_details = @monthly_summary.violation_summary
    weekly_shifts = @monthly_summary.user_weekly_shifts_for_month

    if violation_details.any?
      violation_details
    elsif weekly_shifts.empty?
      ["提出対象の週次シフトが見つかりません（#{@target_year}年#{@target_month}月）"]
    else
      ['制限違反があるため提出できません']
    end
  end

  def parse_weeks_data(weeks_data)
    weeks_data.is_a?(String) ? JSON.parse(weeks_data) : weeks_data
  end

  def find_or_create_weekly_shift(week_data)
    week = Week.find(week_data['id'])
    current_user.weekly_shifts.find_or_create_by(week: week) do |ws|
      ws.submission_year = @target_year
      ws.submission_month = @target_month
    end
  end

  def update_daily_schedules(weekly_shift, week_data)
    week_data['days'].each do |day_data|
      date = Date.parse(day_data['date'])
      daily_schedule = weekly_shift.daily_schedules.find_or_create_by(schedule_date: date)
      update_schedule_times(daily_schedule, week_data['shifts'], day_data['key'])
    end
  end

  def update_schedule_times(daily_schedule, shifts, day_key)
    daily_schedule.update!(
      company_start_time: parse_time(shifts['company']['start'][day_key]),
      company_end_time: parse_time(shifts['company']['end'][day_key]),
      sidejob_start_time: parse_time(shifts['sidejob']['start'][day_key]),
      sidejob_end_time: parse_time(shifts['sidejob']['end'][day_key])
    )
  end

  def build_save_result(errors, success_count)
    {
      success: errors.empty? || params[:submit_type] == 'draft',
      errors: errors,
      saved_weeks: success_count,
    }
  end

  def parse_time(time_string)
    return nil if time_string.blank?

    # HH:MM形式の文字列をそのまま返す（タイムゾーン変換なし）
    # データベースにはstring型で保存されるため、変換不要
    time_string
  end

  def weekly_shift_params
    params.require(:weekly_shift).permit(:status, :violation_warnings)
  end
end
