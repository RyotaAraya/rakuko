# frozen_string_literal: true

module ApplicationHelper
  def pending_approvals_count_for(user)
    return 0 unless user.department_manager?

    # Application の承認待ち
    application_count = Approval
                        .joins(<<-SQL.squish)
        INNER JOIN applications
        ON approvals.approvable_type = 'Application'
        AND approvals.approvable_id = applications.id
                        SQL
                        .where(approval_type: :department, status: :pending)
                        .where(applications: { status: 0 })
                        .count

    # MonthEndClosing の承認待ち
    month_end_closing_count = Approval
                              .joins(<<-SQL.squish)
        INNER JOIN month_end_closings
        ON approvals.approvable_type = 'MonthEndClosing'
        AND approvals.approvable_id = month_end_closings.id
                              SQL
                              .where(approval_type: :department, status: :pending)
                              .where(month_end_closings: { status: 0 })
                              .count

    # Attendance は自動承認なので除外
    application_count + month_end_closing_count
  end

  def role_description(role_name)
    case role_name
    when 'student'
      'シフト提出、勤怠登録、各種申請が可能'
    when 'department_manager'
      '自部署のメンバー管理、申請承認が可能'
    when 'system_admin'
      'システム全体の管理、ユーザー承認が可能'
    else
      ''
    end
  end
end
