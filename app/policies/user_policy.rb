# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def show_shift_requests?
    # 部署担当者は自部署のメンバーのシフトを閲覧可能
    # システム管理者は全員のシフトを閲覧可能
    if user.department_manager?
      record.department_id == user.department_id
    else
      user.system_admin?
    end
  end

  class Scope < Scope
    def resolve
      if user.system_admin?
        scope.all
      elsif user.department_manager?
        scope.where(department_id: user.department_id)
      else
        scope.where(id: user.id)
      end
    end
  end
end
