# frozen_string_literal: true

class ShiftRequestPolicy < ApplicationPolicy
  def new?
    # 学生のみシフト提出可能
    user.student?
  end

  def create?
    # 学生のみシフト作成可能
    user.student?
  end

  def update?
    # 学生のみシフト更新可能
    user.student?
  end

  class Scope < Scope
    def resolve
      if user.student?
        # 学生は自分のシフトのみ閲覧可能
        scope.where(user: user)
      elsif user.department_manager?
        # 部署担当者は自部署のシフトを閲覧可能
        scope.joins(user: :department).where(users: { department_id: user.department_id })
      elsif user.system_admin?
        # システム管理者は全シフトを閲覧可能
        scope.all
      else
        scope.none
      end
    end
  end
end
