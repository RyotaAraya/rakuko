# frozen_string_literal: true

class UpdateMonthEndClosingStatusEnum < ActiveRecord::Migration[7.1]
  def up
    # pending_approval状態(1)を追加するため、既存のclosed(1→2)とlocked(2→3)をずらす
    # 既存データがある場合は、逆順で更新して重複を避ける
    execute <<-SQL.squish
      UPDATE month_end_closings
      SET status = 3
      WHERE status = 2;
    SQL

    execute <<-SQL.squish
      UPDATE month_end_closings
      SET status = 2
      WHERE status = 1;
    SQL

    # status = 0 (open) はそのまま
  end

  def down
    # pending_approval(1)を削除し、closed(2→1)、locked(3→2)に戻す
    # pending_approval状態のレコードはopenに戻す
    execute <<-SQL.squish
      UPDATE month_end_closings
      SET status = 0
      WHERE status = 1;
    SQL

    execute <<-SQL.squish
      UPDATE month_end_closings
      SET status = 1
      WHERE status = 2;
    SQL

    execute <<-SQL.squish
      UPDATE month_end_closings
      SET status = 2
      WHERE status = 3;
    SQL
  end
end
