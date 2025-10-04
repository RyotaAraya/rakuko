# frozen_string_literal: true

class CreateApplications < ActiveRecord::Migration[7.1]
  def change
    create_table :applications do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :application_type
      t.date :application_date
      t.time :start_time
      t.time :end_time
      t.text :reason
      t.integer :status

      t.timestamps
    end
  end
end
