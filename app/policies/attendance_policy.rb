# frozen_string_literal: true

class AttendancePolicy < ApplicationPolicy
  def index?
    # 学生は自分の勤怠、部署担当者は自部署の勤怠、システム管理者は全勤怠を閲覧可能
    user.student? || user.department_manager? || user.system_admin?
  end

  def show?
    # 学生は自分の勤怠のみ
    if user.student?
      record.user_id == user.id
    # 部署担当者は自部署の勤怠
    elsif user.department_manager?
      record.user.department_id == user.department_id
    # システム管理者は全勤怠を閲覧可能
    elsif user.system_admin?
      true
    else
      false
    end
  end

  def today?
    # 学生のみ今日の勤怠画面にアクセス可能
    user.student?
  end

  def weekly?
    # 学生は自分の週間勤怠、部署担当者・システム管理者も閲覧可能
    user.student? || user.department_manager? || user.system_admin?
  end

  class Scope < Scope
    def resolve
      if user.student?
        # 学生は自分の勤怠のみ
        scope.where(user: user)
      elsif user.department_manager?
        # 部署担当者は自部署の勤怠
        scope.joins(user: :department).where(users: { department_id: user.department_id })
      elsif user.system_admin?
        # システム管理者は全勤怠を閲覧可能
        scope.all
      else
        scope.none
      end
    end
  end
end
