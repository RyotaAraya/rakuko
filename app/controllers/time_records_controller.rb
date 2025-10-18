# frozen_string_literal: true

class TimeRecordsController < ApplicationController
  before_action :authenticate_user!

  # 今日の打刻記録を取得
  def today
    @date = Date.current
    @records = current_user.time_records.for_date(@date).ordered_by_time

    render json: {
      date: @date.iso8601,
      records: @records.map do |record|
        {
          id: record.id,
          record_type: record.record_type,
          record_type_display: record.record_type_display_name,
          recorded_at: record.recorded_at.iso8601,
          time_display: record.time_display,
          break_sequence: record.break_sequence,
        }
      end,
      summary: build_today_summary(@records),
    }
  end

  # 出勤打刻
  def clock_in
    @record = current_user.time_records.new(
      date: Date.current,
      record_type: :clock_in,
      recorded_at: Time.current
    )

    if @record.save
      render json: { success: true, record: record_json(@record) }
    else
      render json: { success: false, errors: @record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # 退勤打刻
  def clock_out
    @record = current_user.time_records.new(
      date: Date.current,
      record_type: :clock_out,
      recorded_at: Time.current
    )

    if @record.save
      # 勤怠レコードを自動生成
      attendance = Attendance.generate_from_time_records(current_user, Date.current)
      attendance.save

      render json: {
        success: true,
        record: record_json(@record),
        attendance: attendance_json(attendance),
      }
    else
      render json: { success: false, errors: @record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # 休憩開始打刻
  def break_start
    # 次の休憩シーケンス番号を取得
    last_break = current_user.time_records
                             .for_date(Date.current)
                             .break_records
                             .maximum(:break_sequence) || 0
    next_sequence = last_break + 1

    @record = current_user.time_records.new(
      date: Date.current,
      record_type: :break_start,
      recorded_at: Time.current,
      break_sequence: next_sequence
    )

    if @record.save
      render json: { success: true, record: record_json(@record) }
    else
      render json: { success: false, errors: @record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # 休憩終了打刻
  def break_end
    # 最新の休憩開始のシーケンス番号を取得
    last_break_start = current_user.time_records
                                   .for_date(Date.current)
                                   .where(record_type: :break_start)
                                   .order(break_sequence: :desc)
                                   .first

    unless last_break_start
      render json: { success: false, errors: ['休憩開始の打刻がありません'] }, status: :unprocessable_entity
      return
    end

    # 同じシーケンスで休憩終了が既にあるかチェック
    existing_break_end = current_user.time_records
                                     .for_date(Date.current)
                                     .exists?(record_type: :break_end, break_sequence: last_break_start.break_sequence)

    if existing_break_end
      render json: { success: false, errors: ['この休憩は既に終了しています'] }, status: :unprocessable_entity
      return
    end

    @record = current_user.time_records.new(
      date: Date.current,
      record_type: :break_end,
      recorded_at: Time.current,
      break_sequence: last_break_start.break_sequence
    )

    if @record.save
      render json: { success: true, record: record_json(@record) }
    else
      render json: { success: false, errors: @record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def record_json(record)
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
      status: attendance.status,
    }
  end

  def build_today_summary(records)
    clock_in = records.find(&:record_type_clock_in?)
    clock_out = records.find(&:record_type_clock_out?)
    break_records = records.select(&:break_record?)

    work_hours = if clock_in && clock_out
                   TimeRecord.calculate_work_hours(current_user, Date.current)
                 else
                   0
                 end

    break_minutes = if break_records.any?
                      (TimeRecord.calculate_break_seconds(break_records) / 60).round
                    else
                      0
                    end

    {
      clock_in_time: clock_in&.time_display,
      clock_out_time: clock_out&.time_display,
      work_hours: work_hours,
      break_minutes: break_minutes,
      is_working: clock_in.present? && clock_out.blank?,
    }
  end
end
