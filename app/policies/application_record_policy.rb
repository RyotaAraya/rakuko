# frozen_string_literal: true

# ApplicationRecordPolicyという名前にして、Application（申請）モデルのポリシーとして使用
# Punditのベースとなる ApplicationPolicy と名前が衝突しないように配慮
class ApplicationRecordPolicy < ApplicationPolicy
  def index?
    # 学生は自分の申請のみ、部署担当者は自部署の申請を閲覧可能
    user.student? || user.department_manager? || user.system_admin?
  end

  def show?
    # 学生は自分の申請のみ
    if user.student?
      record.user_id == user.id
    # 部署担当者は自部署の申請
    elsif user.department_manager?
      record.user.department_id == user.department_id
    # システム管理者は全申請を閲覧可能
    elsif user.system_admin?
      true
    else
      false
    end
  end

  def new?
    # 学生のみ申請作成可能
    user.student?
  end

  def create?
    # 学生のみ申請作成可能
    user.student?
  end

  def edit?
    # 学生は自分の未承認申請のみ編集可能
    user.student? && record.user_id == user.id && record.can_edit?
  end

  def update?
    # 学生は自分の未承認申請のみ更新可能
    user.student? && record.user_id == user.id && record.can_edit?
  end

  def destroy?
    # 学生は自分の未承認申請のみ削除可能
    user.student? && record.user_id == user.id && record.can_destroy?
  end

  def cancel?
    # 学生は自分の承認待ち申請のみ取り消し可能
    user.student? && record.user_id == user.id && record.can_cancel?
  end

  class Scope < Scope
    def resolve
      if user.student?
        # 学生は自分の申請のみ
        scope.where(user: user)
      elsif user.department_manager?
        # 部署担当者は自部署の申請
        scope.joins(user: :department).where(users: { department_id: user.department_id })
      elsif user.system_admin?
        # システム管理者は全申請を閲覧可能
        scope.all
      else
        scope.none
      end
    end
  end
end
