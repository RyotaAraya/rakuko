# frozen_string_literal: true

class CreateWeeklyShifts < ActiveRecord::Migration[7.1]
  def change
    create_table :weekly_shifts do |t|
      t.references :user, null: false, foreign_key: true, comment: 'ユーザーID'
      t.references :week, null: false, foreign_key: true, comment: '週ID'
      t.integer :submission_month, null: false, comment: '提出対象月'
      t.integer :submission_year, null: false, comment: '提出対象年'
      t.integer :status, default: 0, comment: 'draft, tentative, confirmed, approved'
      t.text :violation_warnings, comment: '制限違反警告'
      t.datetime :submitted_at, comment: '提出日時'

      t.timestamps
    end

    add_index :weekly_shifts, [:user_id, :week_id], unique: true
    add_index :weekly_shifts, [:user_id, :submission_year, :submission_month]
    add_index :weekly_shifts, :status
  end
end
