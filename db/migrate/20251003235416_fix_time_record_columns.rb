# frozen_string_literal: true

class FixTimeRecordColumns < ActiveRecord::Migration[7.1]
  def change
    rename_column :time_records, :type, :record_type
    rename_column :time_records, :punched_at, :recorded_at
  end
end
