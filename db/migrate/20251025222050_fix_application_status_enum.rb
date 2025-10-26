# frozen_string_literal: true

class FixApplicationStatusEnum < ActiveRecord::Migration[7.1]
  def up
    # pending: 1→0, approved: 2→1, rejected: 3→2 に変更
    execute <<-SQL.squish
      UPDATE applications
      SET status = status - 1
      WHERE status IN (1, 2, 3);
    SQL
  end

  def down
    # 元に戻す: pending: 0→1, approved: 1→2, rejected: 2→3
    execute <<-SQL.squish
      UPDATE applications
      SET status = status + 1
      WHERE status IN (0, 1, 2);
    SQL
  end
end
