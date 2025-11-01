# frozen_string_literal: true

class AttendancesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_attendance, only: [:show]

  # 勤怠一覧
  def index
    authorize Attendance
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month

    # 契約期間内のみ表示
    @available_months = current_user.available_months_for_attendance
    requested_month = Date.new(@year, @month, 1)

    unless @available_months.include?(requested_month)
      # 契約期間内の最新月にリダイレクト
      if @available_months.any?
        latest_month = @available_months.max
        redirect_to attendances_path(year: latest_month.year, month: latest_month.month) and return
      else
        # 契約期間がない場合はエラーメッセージを表示
        flash[:alert] = '契約期間が設定されていません。管理者にお問い合わせください。'
        redirect_to root_path and return
      end
    end

    @attendances = current_user.attendances.for_month(@year, @month).order(date: :asc)
  end

  # 勤怠詳細
  def show
    authorize @attendance
  end

  # 今日の勤怠画面
  def today
    authorize Attendance, :today?
    @date = Date.current
    @time_records = current_user.time_records.for_date(@date).ordered_by_time
    @attendance = current_user.attendances.find_by(date: @date)

    # 今週のシフト予定と実績を取得
    @week_summary = build_week_summary

    respond_to do |format|
      format.html
      format.json do
        render json: {
          date: @date.iso8601,
          time_records: @time_records.map { |r| time_record_json(r) },
          attendance: @attendance ? attendance_json(@attendance) : nil,
          week_summary: @week_summary,
        }
      end
    end
  end

  # 週間勤怠一覧
  def weekly
    authorize Attendance, :weekly?
    # パラメータで日付が指定された場合、その週の始まり（月曜日）を取得
    date = params[:start_date]&.to_date || Date.current
    @start_date = date.beginning_of_week
    @end_date = @start_date.end_of_week

    # 週の中に契約期間内の日が1日でも含まれていればOK
    week_has_valid_date = (@start_date..@end_date).any? { |date| current_user.within_contract_period?(date) }

    unless week_has_valid_date
      respond_to do |format|
        format.html do
          # 契約期間内の今日の日付にリダイレクト（契約期間外の場合は契約開始日）
          fallback_date = if current_user.within_contract_period?(Date.current)
                            Date.current
                          else
                            current_user.contract_start_date
                          end

          redirect_to weekly_attendances_path(start_date: fallback_date) and return
        end
        format.json do
          # JSONリクエストの場合はエラーを返す（リダイレクトループを防ぐ）
          render json: { error: '指定された週は契約期間外です' }, status: :unprocessable_entity and return
        end
      end
    end

    @attendances = current_user.attendances
                               .where(date: @start_date..@end_date)
                               .order(date: :asc)

    # 週間サマリー
    @week_summary = Attendance.weekly_summary(current_user, @start_date)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          start_date: @start_date.iso8601,
          end_date: @end_date.iso8601,
          attendances: @attendances.map { |a| attendance_json(a) },
          week_summary: @week_summary,
        }
      end
    end
  end

  private

  def set_attendance
    @attendance = current_user.attendances.find(params[:id])
  end

  def time_record_json(record)
    {
      id: record.id,
      record_type: record.record_type,
      record_type_display: record.record_type_display_name,
      recorded_at: record.recorded_at.iso8601,
      time_display: record.time_display,
      break_sequence: record.break_sequence,
    }
  end

  def attendance_json(attendance)
    {
      id: attendance.id,
      date: attendance.date.iso8601,
      actual_hours: attendance.actual_hours,
      total_break_time: attendance.total_break_time,
      work_hours_display: attendance.work_hours_display,
      break_time_display: attendance.break_time_display,
    }
  end

  def build_week_summary
    start_date = Date.current.beginning_of_week
    Date.current.end_of_week

    # 今週の実績
    completed_attendances = current_user.attendances
                                        .where(date: start_date...Date.current)

    actual_hours = completed_attendances.sum(:actual_hours)

    # 今週の残りシフト予定
    # TODO: WeeklyShiftから予定時間を取得する実装が必要
    remaining_scheduled_hours = 0

    {
      actual_hours: actual_hours,
      remaining_scheduled_hours: remaining_scheduled_hours,
      predicted_total_hours: actual_hours + remaining_scheduled_hours,
      week_limit: 20,
      over_limit: (actual_hours + remaining_scheduled_hours) > 20,
    }
  end
end
