# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    return unless user_signed_in?

    load_student_data if current_user.student?
    load_department_manager_data if current_user.department_manager?
    load_system_admin_data if current_user.system_admin?
  end

  private

  def load_student_data
    # 今週の労働時間集計と違反チェック
    @week_violations = Attendance.check_weekly_violations(current_user, Date.current.beginning_of_week)
  end

  def load_department_manager_data
    # 承認待ち件数
    @pending_approvals_count = Approval.pending_for_approver(current_user).count
    # 部署メンバー数
    @department_members_count = current_user.department&.users&.count || 0
  end

  def load_system_admin_data
    # 承認待ちユーザー数
    @pending_users_count = User.where(status: :pending).count
    # システム統計
    @total_users_count = User.where(status: :active).count
    @total_departments_count = Department.count
  end
end
