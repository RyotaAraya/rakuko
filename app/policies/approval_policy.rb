# frozen_string_literal: true

class ApprovalPolicy < ApplicationPolicy
  # 承認一覧画面へのアクセス：部署担当者のみ
  def index?
    user.department_manager?
  end

  # 承認アクション：部署担当者のみ、かつ自分が承認者として設定されている
  def approve?
    user.department_manager? && record.approver_id == user.id
  end

  # 却下アクション：部署担当者のみ、かつ自分が承認者として設定されている
  def reject?
    user.department_manager? && record.approver_id == user.id
  end

  class Scope < Scope
    def resolve
      if user.department_manager?
        # 部署担当者は自分が承認者となっている承認レコードのみ表示
        scope.where(approver_id: user.id)
      else
        scope.none
      end
    end
  end
end
