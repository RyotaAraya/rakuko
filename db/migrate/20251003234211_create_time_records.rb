# frozen_string_literal: true

class CreateTimeRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :time_records do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date
      t.integer :type
      t.datetime :punched_at
      t.integer :break_sequence

      t.timestamps
    end
  end
end
