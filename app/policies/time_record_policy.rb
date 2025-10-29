# frozen_string_literal: true

class TimeRecordPolicy < ApplicationPolicy
  def today?
    # 学生のみ打刻可能
    user.student?
  end

  def clock_in?
    # 学生のみ出勤打刻可能
    user.student?
  end

  def clock_out?
    # 学生のみ退勤打刻可能
    user.student?
  end

  def break_start?
    # 学生のみ休憩開始打刻可能
    user.student?
  end

  def break_end?
    # 学生のみ休憩終了打刻可能
    user.student?
  end

  class Scope < Scope
    def resolve
      if user.student?
        # 学生は自分の打刻記録のみ閲覧可能
        scope.where(user: user)
      elsif user.department_manager?
        # 部署担当者は自部署の学生の打刻記録を閲覧可能
        scope.joins(user: :department).where(users: { department_id: user.department_id })
      elsif user.system_admin?
        # システム管理者は全打刻記録を閲覧可能
        scope.all
      else
        scope.none
      end
    end
  end
end
