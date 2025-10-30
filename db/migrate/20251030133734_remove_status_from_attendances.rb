# frozen_string_literal: true

class RemoveStatusFromAttendances < ActiveRecord::Migration[7.1]
  def change
    remove_column :attendances, :status, :integer
  end
end
