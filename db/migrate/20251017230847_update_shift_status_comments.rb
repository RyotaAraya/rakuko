class UpdateShiftStatusComments < ActiveRecord::Migration[7.1]
  def up
    # WeeklyShiftsテーブルのstatusカラムコメントを更新
    change_column_comment :weekly_shifts, :status, from: 'draft, tentative, confirmed, approved', to: 'draft, submitted'

    # MonthlySummariesテーブルのstatusカラムコメントを更新
    change_column_comment :monthly_summaries, :status, from: 'draft, submitted, approved, rejected', to: 'draft, submitted'
  end

  def down
    # ロールバック時は元のコメントに戻す
    change_column_comment :weekly_shifts, :status, from: 'draft, submitted', to: 'draft, tentative, confirmed, approved'
    change_column_comment :monthly_summaries, :status, from: 'draft, submitted', to: 'draft, submitted, approved, rejected'
  end
end
