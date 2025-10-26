# frozen_string_literal: true

class MonthEndClosingPolicy < ApplicationPolicy
  def index?
    true # 全ユーザーがアクセス可能
  end

  def show?
    user.system_admin? || user.department_manager? || record.user_id == user.id
  end

  def submit_for_approval?
    # 学生は自分の月末締めを承認申請可能
    user.student? && record.user_id == user.id
  end

  def approve?
    # 部署担当者は自部署メンバーの月末締めを承認可能
    # システム管理者は承認権限なし
    user.department_manager? && record.user.department_id == user.department_id
  end

  def reject?
    # 却下権限は承認権限と同じ
    approve?
  end

  def reopen?
    # 部署担当者は自部署メンバーの承認済み月末締めを再開可能
    user.department_manager? && record.user.department_id == user.department_id
  end

  def update_checklist?
    true # 学生が自分のチェックリストを更新
  end

  class Scope < Scope
    def resolve
      if user.system_admin?
        scope.all
      elsif user.department_manager?
        scope.joins(:user).where(users: { department_id: user.department_id })
      else
        scope.where(user_id: user.id)
      end
    end
  end
end
