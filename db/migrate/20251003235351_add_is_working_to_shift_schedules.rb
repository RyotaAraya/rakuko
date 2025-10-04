# frozen_string_literal: true

class AddIsWorkingToShiftSchedules < ActiveRecord::Migration[7.1]
  def change
    add_column :shift_schedules, :is_working, :boolean
  end
end
