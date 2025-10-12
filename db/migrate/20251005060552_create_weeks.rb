class CreateWeeks < ActiveRecord::Migration[7.1]
  def change
    create_table :weeks do |t|
      t.date :start_date, null: false, comment: '週開始日（月曜日）'
      t.date :end_date, null: false, comment: '週終了日（日曜日）'
      t.integer :year, null: false, comment: '年'
      t.integer :week_number, null: false, comment: '年内週番号'
      t.boolean :is_cross_month, default: false, comment: '月跨ぎ週フラグ'

      t.timestamps
    end

    add_index :weeks, [:year, :week_number], unique: true
    add_index :weeks, :start_date
    add_index :weeks, :is_cross_month
  end
end
