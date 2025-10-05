class CreateMonthlySummaries < ActiveRecord::Migration[7.1]
  def change
    create_table :monthly_summaries do |t|
      t.references :user, null: false, foreign_key: true, comment: 'ユーザーID'
      t.integer :target_year, null: false, comment: '対象年'
      t.integer :target_month, null: false, comment: '対象月'
      t.decimal :total_company_hours, precision: 5, scale: 2, default: 0, comment: '月間弊社合計時間'
      t.decimal :total_sidejob_hours, precision: 5, scale: 2, default: 0, comment: '月間掛け持ち合計時間'
      t.decimal :total_hours, precision: 5, scale: 2, default: 0, comment: '月間合計時間'
      t.integer :status, default: 0, comment: 'draft, submitted, approved, rejected'
      t.datetime :submitted_at, comment: '提出日時'

      t.timestamps
    end

    add_index :monthly_summaries, [:user_id, :target_year, :target_month], unique: true
    add_index :monthly_summaries, :status
  end
end
