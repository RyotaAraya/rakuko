# frozen_string_literal: true

class RemoveLaborApprovals < ActiveRecord::Migration[7.1]
  def up
    # 労務承認レコード（approval_type = 1）を削除
    Approval.where(approval_type: 1).delete_all
  end

  def down
    # ロールバック時は何もしない（データ復元不可）
  end
end
