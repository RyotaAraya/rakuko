# frozen_string_literal: true

class CreateMonthEndClosings < ActiveRecord::Migration[7.1]
  def change
    create_table :month_end_closings do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year
      t.integer :month
      t.integer :status
      t.decimal :total_work_hours
      t.integer :total_work_days
      t.decimal :overtime_hours
      t.datetime :closed_at
      t.references :closed_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
