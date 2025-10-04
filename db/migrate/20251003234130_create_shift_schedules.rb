# frozen_string_literal: true

class CreateShiftSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :shift_schedules do |t|
      t.references :shift, null: false, foreign_key: true
      t.date :date
      t.time :company_start_time
      t.time :company_end_time
      t.time :part_time_start_time
      t.time :part_time_end_time

      t.timestamps
    end
  end
end
