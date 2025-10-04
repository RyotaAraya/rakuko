# frozen_string_literal: true

class CreateAttendances < ActiveRecord::Migration[7.1]
  def change
    create_table :attendances do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date
      t.decimal :actual_hours
      t.integer :total_break_time
      t.boolean :is_auto_generated
      t.integer :status

      t.timestamps
    end
  end
end
