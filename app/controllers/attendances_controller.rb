# frozen_string_literal: true

class AttendancesController < ApplicationController
  before_action :authenticate_user!

  # 勤怠一覧
  def index
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month
    @attendances = current_user.attendances.for_month(@year, @month).order(date: :asc)
  end

  # 勤怠詳細
  def show
    @attendance = current_user.attendances.find(params[:id])
  end

  # 今日の勤怠画面
  def today
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
          week_summary: @week_summary
        }
      end
    end
  end

  # 週間勤怠一覧
  def weekly
    @start_date = params[:start_date]&.to_date || Date.current.beginning_of_week
    @end_date = @start_date.end_of_week

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
          week_summary: @week_summary
        }
      end
    end
  end

  private

  def time_record_json(record)
    {
      id: record.id,
      record_type: record.record_type,
      record_type_display: record.record_type_display_name,
      recorded_at: record.recorded_at.iso8601,
      time_display: record.time_display,
      break_sequence: record.break_sequence
    }
  end

  def attendance_json(attendance)
    {
      id: attendance.id,
      date: attendance.date.iso8601,
      actual_hours: attendance.actual_hours,
      total_break_time: attendance.total_break_time,
      status: attendance.status,
      status_display: attendance.status_display_name,
      work_hours_display: attendance.work_hours_display,
      break_time_display: attendance.break_time_display
    }
  end

  def build_week_summary
    start_date = Date.current.beginning_of_week
    end_date = Date.current.end_of_week

    # 今週の実績（承認済み）
    completed_attendances = current_user.attendances
                                         .where(date: start_date...Date.current)
                                         .approved

    actual_hours = completed_attendances.sum(:actual_hours)

    # 今週の残りシフト予定
    # TODO: WeeklyShiftから予定時間を取得する実装が必要
    remaining_scheduled_hours = 0

    {
      actual_hours: actual_hours,
      remaining_scheduled_hours: remaining_scheduled_hours,
      predicted_total_hours: actual_hours + remaining_scheduled_hours,
      week_limit: 20,
      over_limit: (actual_hours + remaining_scheduled_hours) > 20
    }
  end
end
