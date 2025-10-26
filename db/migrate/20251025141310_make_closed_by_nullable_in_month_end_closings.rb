# frozen_string_literal: true

class MakeClosedByNullableInMonthEndClosings < ActiveRecord::Migration[7.1]
  def change
    change_column_null :month_end_closings, :closed_by_id, true
    change_column_null :month_end_closings, :closed_at, true
  end
end
