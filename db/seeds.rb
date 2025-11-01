# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

Rails.logger.debug 'Setting up roles and departments...'

# 1. 初期ロールの作成（ER図準拠）
Rails.logger.debug 'Creating roles...'
Role.seed_data.each do |role_data|
  role = Role.find_or_create_by(name: role_data[:name]) do |r|
    r.description = role_data[:description]
  end
  Rails.logger.debug { "✓ Role: #{role.display_name} (#{role.name})" }
end

# 2. 初期部署の作成
Rails.logger.debug 'Creating departments...'
initial_departments = [
  { name: '情報システム部', department_type: :management, description: 'システム管理・運用を担当' },
  { name: '営業部', department_type: :general, description: '営業活動を担当する一般事業部' },
  { name: '開発部', department_type: :general, description: 'プロダクト開発を担当する一般事業部' },
]

initial_departments.each do |dept_data|
  dept = Department.find_or_create_by(name: dept_data[:name]) do |d|
    d.department_type = dept_data[:department_type]
    d.description = dept_data[:description]
  end
  Rails.logger.debug { "✓ Department: #{dept.name} (#{dept.type_display_name})" }
end

Rails.logger.debug 'Creating development user accounts...'

# 3. 開発用ユーザーアカウントを作成
development_users = [
  {
    email: 'student@example.com',
    first_name: '学生',
    last_name: '太郎',
    roles: [:student],
    status: :active,
    department: '営業部',
  },
  {
    email: 'department.manager@example.com',
    first_name: '部署',
    last_name: '管理者',
    roles: [:department_manager],
    status: :active,
    department: '営業部',
  },
  {
    email: 'system.admin@example.com',
    first_name: 'システム',
    last_name: '管理者',
    roles: [:system_admin],
    status: :active,
    department: '情報システム部',
  },
  {
    email: 'pending.user@example.com',
    first_name: '承認待ち',
    last_name: 'ユーザー',
    roles: [], # 承認待ちは権限なし
    status: :pending,
    department: nil,
  },
]

development_users.each do |user_attrs|
  user = User.find_or_initialize_by(email: user_attrs[:email])

  if user.new_record?
    # 部署の取得
    department = Department.find_by(name: user_attrs[:department]) if user_attrs[:department]

    user.assign_attributes(
      first_name: user_attrs[:first_name],
      last_name: user_attrs[:last_name],
      status: user_attrs[:status],
      department: department,
      google_uid: "dev_#{user_attrs[:email].split('@')[0]}",
      password: 'password123',
      password_confirmation: 'password123'
    )

    # 学生ユーザーには契約終了日を設定（契約開始日はcreated_atを使用）
    if user_attrs[:roles].include?(:student)
      current_date = Date.current
      user.contract_end_date = (current_date + 6.months).end_of_month
      user.contract_updated_at = Time.current
    end

    if user.save
      # 新しい権限システムで権限を設定
      user_attrs[:roles].each do |role_name|
        user.add_role(role_name)
      end
      Rails.logger.debug { "✓ Created user: #{user.email} (#{user_attrs[:roles].join(', ')})" }
    else
      Rails.logger.debug { "✗ Failed to create user: #{user.email} - #{user.errors.full_messages.join(', ')}" }
    end
  else
    # 既存ユーザーでも学生で契約終了日がない場合は設定
    if user_attrs[:roles].include?(:student) && user.contract_end_date.nil?
      current_date = Date.current
      user.update(
        contract_end_date: (current_date + 6.months).end_of_month,
        contract_updated_at: Time.current
      )
      Rails.logger.debug { "✓ Updated contract period for: #{user.email}" }
    end
    Rails.logger.debug { "✓ User already exists: #{user.email} (#{user.role_display_names})" }
  end
end

Rails.logger.debug 'Development user accounts setup complete!'

# 4. 週次シフトデータの作成（新設計）
Rails.logger.debug 'Creating sample weekly shift data...'
student_user = User.find_by(email: 'student@example.com')

if student_user
  # 今月と来月の月次サマリーを作成
  current_date = Date.current
  [current_date, current_date.next_month].each do |date|
    WeekManagementService.create_monthly_summary_with_shifts(
      student_user,
      date.year,
      date.month
    )

    Rails.logger.debug { "✓ Created monthly summary for #{date.strftime('%Y年%m月')}" }
  end
end

# 5. 勤怠データの作成（先月分）
Rails.logger.debug 'Creating sample attendance data...'
if student_user
  last_month = Date.current.last_month

  # 先月の平日に勤怠記録を作成
  (1..Date.new(last_month.year, last_month.month, -1).day).each do |day|
    work_date = Date.new(last_month.year, last_month.month, day)
    next if [0, 6].include?(work_date.wday) # 土日はスキップ

    # タイムレコードの作成
    clock_in_time = work_date.beginning_of_day + 13.hours + rand(0..30).minutes
    break_start_time = clock_in_time + 2.hours + rand(0..30).minutes
    break_end_time = break_start_time + 1.hour
    clock_out_time = clock_in_time + 4.hours + rand(0..30).minutes

    [
      { record_type: :clock_in, recorded_at: clock_in_time, break_sequence: nil },
      { record_type: :break_start, recorded_at: break_start_time, break_sequence: 1 },
      { record_type: :break_end, recorded_at: break_end_time, break_sequence: 1 },
      { record_type: :clock_out, recorded_at: clock_out_time, break_sequence: nil },
    ].each do |record_data|
      student_user.time_records.find_or_create_by(
        date: work_date,
        record_type: record_data[:record_type]
      ) do |record|
        record.recorded_at = record_data[:recorded_at]
        record.break_sequence = record_data[:break_sequence]
      end
    end

    # 勤怠記録の作成
    student_user.attendances.find_or_create_by(date: work_date) do |att|
      att.actual_hours = 4
      att.total_break_time = 60
      att.is_auto_generated = true
    end
  end

  Rails.logger.debug { "✓ Created attendance records for #{last_month.strftime('%Y年%m月')}" }
end

# 6. 申請データの作成
Rails.logger.debug 'Creating sample application data...'
if student_user
  # 来週の申請を作成
  next_week = Date.current.next_week

  # 遅刻申請
  student_user.applications.find_or_create_by(
    application_type: :late,
    application_date: next_week
  ) do |app|
    app.start_time = Time.zone.parse('10:00')
    app.reason = '電車の遅延により遅刻いたします。'
    app.status = :pending
  end

  # 早退申請
  student_user.applications.find_or_create_by(
    application_type: :early_leave,
    application_date: next_week + 2.days
  ) do |app|
    app.end_time = Time.zone.parse('16:00')
    app.reason = '病院への通院のため早退させていただきます。'
    app.status = :approved
  end

  Rails.logger.debug '✓ Created sample applications'
end

# 7. 月末締めデータの作成
Rails.logger.debug 'Creating sample month-end closing data...'
if student_user
  department_manager = User.find_by(email: 'department.manager@example.com')
  last_month = Date.current.last_month

  # 承認済みの月末締め
  student_user.month_end_closings.find_or_create_by(
    year: last_month.year,
    month: last_month.month
  ) do |closing|
    closing.status = :closed
    closing.total_work_hours = 80
    closing.total_work_days = 20
    closing.overtime_hours = 0
    closing.closed_by = department_manager
    closing.closed_at = last_month.end_of_month
  end

  # 今月の承認待ち締め
  current_month = Date.current
  student_user.month_end_closings.find_or_create_by(
    year: current_month.year,
    month: current_month.month
  ) do |closing|
    closing.status = :pending_approval
    closing.total_work_hours = 60
    closing.total_work_days = 15
    closing.overtime_hours = 0
  end

  Rails.logger.debug { "✓ Created month-end closing for #{last_month.strftime('%Y年%m月')}" }
end

# 8. 承認データの作成（週次シフト用）
# Rails.logger.debug 'Creating sample approval data...'
# TODO: 承認機能は後のフェーズで実装予定
# if student_user
#   department_manager = User.find_by(email: 'department.manager@example.com')
#   hr_manager = User.find_by(email: 'hr.manager@example.com')
#
#   # 月次サマリーの承認
#   monthly_summary = student_user.monthly_summaries.first
#   if monthly_summary
#     # 部署承認
#     monthly_summary.approvals.find_or_create_by(
#       approval_type: :department_approval,
#       approver: department_manager
#     ) do |approval|
#       approval.status = :approved
#       approval.comment = 'シフト内容を確認しました。'
#       approval.approved_at = Time.current
#     end
#
#     # 労務承認
#     monthly_summary.approvals.find_or_create_by(
#       approval_type: :labor_approval,
#       approver: hr_manager
#     ) do |approval|
#       approval.status = :pending
#     end
#   end
#
#   Rails.logger.debug '✓ Created sample approval records'
# end

# 9. 通知データの作成
Rails.logger.debug 'Creating sample notification data...'
if student_user
  # シフト提出リマインダー
  student_user.notifications.find_or_create_by(
    notification_type: :shift_reminder,
    title: 'シフト提出リマインダー'
  ) do |notification|
    notification.message = "#{Date.current.next_month.strftime('%Y年%m月')}のシフトを提出してください。"
    notification.priority = :normal
    notification.action_url = '/shifts/new'
    notification.notifiable = student_user
  end

  # 承認完了通知
  student_user.notifications.find_or_create_by(
    notification_type: :approval_approved,
    title: '承認完了'
  ) do |notification|
    notification.message = 'シフト申請が承認されました。'
    notification.priority = :normal
    notification.read_at = 1.hour.ago
    notification.notifiable = student_user
  end

  Rails.logger.debug '✓ Created sample notifications'
end

Rails.logger.debug ''
Rails.logger.debug 'All sample data created successfully!'
Rails.logger.debug ''
Rails.logger.debug 'Available test accounts:'
Rails.logger.debug '========================'
Rails.logger.debug '学生ユーザー: student@example.com'
Rails.logger.debug '部署管理者: department.manager@example.com'
Rails.logger.debug 'システム管理者: system.admin@example.com'
Rails.logger.debug '承認待ちユーザー: pending.user@example.com'
Rails.logger.debug ''
Rails.logger.debug '共通パスワード: password123'
Rails.logger.debug 'ログインURL: /users/sign_in'
Rails.logger.debug ''
Rails.logger.debug 'Sample data includes:'
Rails.logger.debug '- Shifts for current and next month'
Rails.logger.debug '- Attendance records for last month'
Rails.logger.debug '- Various application types'
Rails.logger.debug '- Approval workflows'
Rails.logger.debug '- Notification samples'
Rails.logger.debug '- Month-end closing records'
Rails.logger.debug ''
Rails.logger.debug '注意: これらは開発環境専用のアカウントです。'
