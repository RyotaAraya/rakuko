class ChangeTimeColumnsToStringInDailySchedules < ActiveRecord::Migration[7.1]
  def up
    # 既存データを文字列形式に変換してから型を変更
    change_column :daily_schedules, :company_start_time, :string, limit: 8
    change_column :daily_schedules, :company_end_time, :string, limit: 8
    change_column :daily_schedules, :sidejob_start_time, :string, limit: 8
    change_column :daily_schedules, :sidejob_end_time, :string, limit: 8

    # カラムのコメントを更新
    change_column_comment :daily_schedules, :company_start_time, from: '弊社勤務開始時間', to: '弊社勤務開始時間 (HH:MM形式)'
    change_column_comment :daily_schedules, :company_end_time, from: '弊社勤務終了時間', to: '弊社勤務終了時間 (HH:MM形式)'
    change_column_comment :daily_schedules, :sidejob_start_time, from: '掛け持ち開始時間', to: '掛け持ち開始時間 (HH:MM形式)'
    change_column_comment :daily_schedules, :sidejob_end_time, from: '掛け持ち終了時間', to: '掛け持ち終了時間 (HH:MM形式)'
  end

  def down
    change_column :daily_schedules, :company_start_time, :time
    change_column :daily_schedules, :company_end_time, :time
    change_column :daily_schedules, :sidejob_start_time, :time
    change_column :daily_schedules, :sidejob_end_time, :time

    change_column_comment :daily_schedules, :company_start_time, from: '弊社勤務開始時間 (HH:MM形式)', to: '弊社勤務開始時間'
    change_column_comment :daily_schedules, :company_end_time, from: '弊社勤務終了時間 (HH:MM形式)', to: '弊社勤務終了時間'
    change_column_comment :daily_schedules, :sidejob_start_time, from: '掛け持ち開始時間 (HH:MM形式)', to: '掛け持ち開始時間'
    change_column_comment :daily_schedules, :sidejob_end_time, from: '掛け持ち終了時間 (HH:MM形式)', to: '掛け持ち終了時間'
  end
end
