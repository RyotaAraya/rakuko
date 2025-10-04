# frozen_string_literal: true

class CreateShifts < ActiveRecord::Migration[7.1]
  def change
    create_table :shifts do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year
      t.integer :month
      t.integer :status
      t.text :violation_warnings
      t.datetime :submitted_at

      t.timestamps
    end
  end
end
