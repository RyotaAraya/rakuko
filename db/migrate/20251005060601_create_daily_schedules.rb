# frozen_string_literal: true

class CreateDailySchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :daily_schedules do |t|
      t.references :weekly_shift, null: false, foreign_key: true, comment: '週間シフトID'
      t.date :schedule_date, null: false, comment: 'スケジュール日付'
      t.time :company_start_time, comment: '弊社勤務開始時間'
      t.time :company_end_time, comment: '弊社勤務終了時間'
      t.time :sidejob_start_time, comment: '掛け持ち開始時間'
      t.time :sidejob_end_time, comment: '掛け持ち終了時間'
      t.decimal :company_actual_hours, precision: 4, scale: 2, comment: '弊社実労働時間'
      t.decimal :sidejob_actual_hours, precision: 4, scale: 2, comment: '掛け持ち実労働時間'

      t.timestamps
    end

    add_index :daily_schedules, [:weekly_shift_id, :schedule_date], unique: true
    add_index :daily_schedules, :schedule_date
  end
end
