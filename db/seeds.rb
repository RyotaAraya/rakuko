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
  { name: '人事部', department_type: :general, description: '人事・労務を担当する一般事業部' },
  { name: 'マーケティング部', department_type: :general, description: 'マーケティング活動を担当する一般事業部' },
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
  # システム管理者
  {
    email: 'system.admin@example.com',
    first_name: 'システム',
    last_name: '管理者',
    roles: [:system_admin],
    status: :active,
    department: '情報システム部',
  },

  # 部署管理者（各部署）
  {
    email: 'sales.manager@example.com',
    first_name: '営業',
    last_name: '部長',
    roles: [:department_manager],
    status: :active,
    department: '営業部',
  },
  {
    email: 'dev.manager@example.com',
    first_name: '開発',
    last_name: '部長',
    roles: [:department_manager],
    status: :active,
    department: '開発部',
  },
  {
    email: 'hr.manager@example.com',
    first_name: '人事',
    last_name: '部長',
    roles: [:department_manager],
    status: :active,
    department: '人事部',
  },

  # 学生アルバイト（営業部）
  {
    email: 'student1@example.com',
    first_name: '太郎',
    last_name: '田中',
    roles: [:student],
    status: :active,
    department: '営業部',
  },
  {
    email: 'student2@example.com',
    first_name: '花子',
    last_name: '佐藤',
    roles: [:student],
    status: :active,
    department: '営業部',
  },

  # 学生アルバイト（開発部）
  {
    email: 'student3@example.com',
    first_name: '次郎',
    last_name: '鈴木',
    roles: [:student],
    status: :active,
    department: '開発部',
  },
  {
    email: 'student4@example.com',
    first_name: '美咲',
    last_name: '高橋',
    roles: [:student],
    status: :active,
    department: '開発部',
  },

  # 学生アルバイト（人事部）
  {
    email: 'student5@example.com',
    first_name: '健太',
    last_name: '伊藤',
    roles: [:student],
    status: :active,
    department: '人事部',
  },

  # 学生アルバイト（マーケティング部）
  {
    email: 'student6@example.com',
    first_name: '愛',
    last_name: '渡辺',
    roles: [:student],
    status: :active,
    department: 'マーケティング部',
  },

  # 承認待ちユーザー（複数）
  {
    email: 'pending1@example.com',
    first_name: '承認待ち',
    last_name: 'ユーザー1',
    roles: [],
    status: :pending,
    department: nil,
  },
  {
    email: 'pending2@example.com',
    first_name: '承認待ち',
    last_name: 'ユーザー2',
    roles: [],
    status: :pending,
    department: nil,
  },
  {
    email: 'pending3@example.com',
    first_name: '承認待ち',
    last_name: 'ユーザー3',
    roles: [],
    status: :pending,
    department: nil,
  },
  {
    email: 'pending4@example.com',
    first_name: '承認待ち',
    last_name: 'ユーザー4',
    roles: [],
    status: :pending,
    department: nil,
  },
  {
    email: 'pending5@example.com',
    first_name: '承認待ち',
    last_name: 'ユーザー5',
    roles: [],
    status: :pending,
    department: nil,
  },

  # 非アクティブユーザー
  {
    email: 'inactive@example.com',
    first_name: '退職',
    last_name: 'ユーザー',
    roles: [:student],
    status: :inactive,
    department: '営業部',
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

# 4. 週次シフトデータの作成（複数学生分）
Rails.logger.debug 'Creating sample weekly shift data...'
student_users = User.joins(:user_roles).joins('INNER JOIN roles ON user_roles.role_id = roles.id')
                    .where(roles: { name: 'student' }, status: :active)

student_users.each do |student|
  # 今月と来月の月次サマリーを作成
  current_date = Date.current
  [current_date, current_date.next_month].each do |date|
    WeekManagementService.create_monthly_summary_with_shifts(
      student,
      date.year,
      date.month
    )
  end
  Rails.logger.debug { "✓ Created shift data for #{student.full_name}" }
end

# 5. 勤怠データの作成（先月分＋今月分の一部）
Rails.logger.debug 'Creating sample attendance data...'
student_users.each_with_index do |student, index|
  # 先月の勤怠データ
  last_month = Date.current.last_month
  work_days_last_month = (1..last_month.end_of_month.day).map { |day|
    Date.new(last_month.year, last_month.month, day)
  }.reject { |date| [0, 6].include?(date.wday) } # 土日除外

  work_days_last_month.each do |work_date|
    # 各学生で勤務パターンを変える
    work_hours = [3, 4, 5, 6][index % 4]
    clock_in_hour = [9, 10, 13, 14][index % 4]

    clock_in_time = work_date.beginning_of_day + clock_in_hour.hours + rand(0..30).minutes
    break_start_time = clock_in_time + 2.hours + rand(0..30).minutes
    break_end_time = break_start_time + 1.hour
    clock_out_time = clock_in_time + work_hours.hours + 1.hour + rand(0..30).minutes

    [
      { record_type: :clock_in, recorded_at: clock_in_time, break_sequence: nil },
      { record_type: :break_start, recorded_at: break_start_time, break_sequence: 1 },
      { record_type: :break_end, recorded_at: break_end_time, break_sequence: 1 },
      { record_type: :clock_out, recorded_at: clock_out_time, break_sequence: nil },
    ].each do |record_data|
      student.time_records.find_or_create_by(
        date: work_date,
        record_type: record_data[:record_type],
        break_sequence: record_data[:break_sequence]
      ) do |record|
        record.recorded_at = record_data[:recorded_at]
      end
    end

    # 勤怠記録の作成
    student.attendances.find_or_create_by(date: work_date) do |att|
      att.actual_hours = work_hours
      att.total_break_time = 60
      att.is_auto_generated = true
    end
  end

  # 今月の勤怠データ（月初から今日まで）
  current_month = Date.current
  work_days_this_month = (1..current_month.day).map { |day|
    Date.new(current_month.year, current_month.month, day)
  }.reject { |date| [0, 6].include?(date.wday) } # 土日除外

  work_days_this_month.each do |work_date|
    next if work_date > Date.current # 未来の日付はスキップ

    work_hours = [3, 4, 5, 6][index % 4]
    clock_in_hour = [9, 10, 13, 14][index % 4]

    clock_in_time = work_date.beginning_of_day + clock_in_hour.hours + rand(0..30).minutes
    break_start_time = clock_in_time + 2.hours + rand(0..30).minutes
    break_end_time = break_start_time + 1.hour
    clock_out_time = clock_in_time + work_hours.hours + 1.hour + rand(0..30).minutes

    [
      { record_type: :clock_in, recorded_at: clock_in_time, break_sequence: nil },
      { record_type: :break_start, recorded_at: break_start_time, break_sequence: 1 },
      { record_type: :break_end, recorded_at: break_end_time, break_sequence: 1 },
      { record_type: :clock_out, recorded_at: clock_out_time, break_sequence: nil },
    ].each do |record_data|
      student.time_records.find_or_create_by(
        date: work_date,
        record_type: record_data[:record_type],
        break_sequence: record_data[:break_sequence]
      ) do |record|
        record.recorded_at = record_data[:recorded_at]
      end
    end

    # 勤怠記録の作成
    student.attendances.find_or_create_by(date: work_date) do |att|
      att.actual_hours = work_hours
      att.total_break_time = 60
      att.is_auto_generated = true
    end
  end

  Rails.logger.debug { "✓ Created attendance records for #{student.full_name}" }
end

# 6. 申請データの作成（様々な状態）
Rails.logger.debug 'Creating sample application data...'
student_users.each_with_index do |student, index|
  next_week = Date.current.next_week
  department_manager = student.department.users
                              .joins(:user_roles)
                              .joins('INNER JOIN roles ON user_roles.role_id = roles.id')
                              .where(roles: { name: 'department_manager' })
                              .first

  # 各学生に複数の申請を作成
  applications_data = [
    # 承認待ち遅刻申請
    {
      type: :late,
      date: next_week,
      start_time: '10:00',
      reason: '電車の遅延により遅刻いたします。',
      status: :pending,
    },
    # 承認待ち早退申請
    {
      type: :early_leave,
      date: next_week + 1.day,
      end_time: '16:00',
      reason: '病院への通院のため早退させていただきます。',
      status: :pending,
    },
    # 承認待ち欠勤申請
    {
      type: :absence,
      date: next_week + 2.days,
      reason: '体調不良のため欠勤いたします。',
      status: :pending,
    },
  ]

  # 承認済み・却下済みの申請も追加（過去の日付）
  last_week = Date.current.last_week
  past_applications = [
    {
      type: :late,
      date: last_week,
      start_time: '10:30',
      reason: '交通機関の遅延のため',
      status: :approved,
    },
    {
      type: :absence,
      date: last_week + 1.day,
      reason: '大学の試験のため欠勤いたします。',
      status: :approved,
    },
    {
      type: :early_leave,
      date: last_week + 2.days,
      end_time: '15:00',
      reason: '私用のため',
      status: :rejected,
    },
  ]

  # 承認待ち申請を作成（承認レコードも作成）
  applications_data.take(index % 3 + 1).each do |app_data|
    application = student.applications.find_or_create_by(
      application_type: app_data[:type],
      application_date: app_data[:date]
    ) do |app|
      app.start_time = Time.zone.parse(app_data[:start_time]) if app_data[:start_time]
      app.end_time = Time.zone.parse(app_data[:end_time]) if app_data[:end_time]
      app.reason = app_data[:reason]
      app.status = app_data[:status]
    end

    # 承認待ちの場合、Approvalレコードを作成
    if application.status == 'pending' && department_manager && !application.approvals.exists?
      application.approvals.create!(
        approval_type: :department,
        status: :pending,
        approver: department_manager
      )
    end
  end

  # 過去の申請（承認済み・却下済み）を作成
  past_applications.take(index % 2 + 1).each do |app_data|
    student.applications.find_or_create_by(
      application_type: app_data[:type],
      application_date: app_data[:date]
    ) do |app|
      app.start_time = Time.zone.parse(app_data[:start_time]) if app_data[:start_time]
      app.end_time = Time.zone.parse(app_data[:end_time]) if app_data[:end_time]
      app.reason = app_data[:reason]
      app.status = app_data[:status]
    end
  end

  Rails.logger.debug { "✓ Created applications for #{student.full_name}" }
end

# 7. 月末締めデータの作成
Rails.logger.debug 'Creating sample month-end closing data...'
student_users.each_with_index do |student, index|
  last_month = Date.current.last_month

  # 先月の締め（承認済み）
  student.month_end_closings.find_or_create_by(
    year: last_month.year,
    month: last_month.month
  ) do |closing|
    closing.status = :closed
    closing.total_work_hours = [60, 70, 75, 80][index % 4]
    closing.total_work_days = [15, 17, 18, 20][index % 4]
    closing.overtime_hours = 0
    closing.closed_by = student.department.users.joins(:user_roles).joins('INNER JOIN roles ON user_roles.role_id = roles.id')
                              .where(roles: { name: 'department_manager' }).first
    closing.closed_at = last_month.end_of_month
  end

  # 今月の締め（状態は様々）
  current_month = Date.current
  status = [:open, :pending_approval, :closed][index % 3]
  department_manager = student.department.users
                              .joins(:user_roles)
                              .joins('INNER JOIN roles ON user_roles.role_id = roles.id')
                              .where(roles: { name: 'department_manager' })
                              .first

  closing = student.month_end_closings.find_or_create_by(
    year: current_month.year,
    month: current_month.month
  ) do |c|
    c.status = status
    c.total_work_hours = [40, 50, 55, 60][index % 4]
    c.total_work_days = [10, 12, 13, 15][index % 4]
    c.overtime_hours = 0
    if status == :closed
      c.closed_by = department_manager
      c.closed_at = Time.current
    end
  end

  # 承認待ちの場合、Approvalレコードを作成
  if closing.status == 'pending_approval' && department_manager && !closing.approvals.exists?
    closing.approvals.create!(
      approval_type: :department,
      status: :pending,
      approver: department_manager
    )
  end

  Rails.logger.debug { "✓ Created month-end closing for #{student.full_name}" }
end

# 8. 通知データの作成（複数パターン）
Rails.logger.debug 'Creating sample notification data...'
student_users.each_with_index do |student, index|
  case index % 4
  when 0
    # シフト提出リマインダー（未読）
    student.notifications.find_or_create_by(
      notification_type: :shift_reminder,
      title: 'シフト提出リマインダー'
    ) do |notification|
      notification.message = "#{Date.current.next_month.strftime('%Y年%m月')}のシフトを提出してください。"
      notification.priority = :normal
      notification.action_url = '/shifts/new'
      notification.notifiable = student
    end
  when 1
    # 承認完了通知（既読）
    student.notifications.find_or_create_by(
      notification_type: :approval_approved,
      title: '申請が承認されました'
    ) do |notification|
      notification.message = '早退申請が承認されました。'
      notification.priority = :normal
      notification.read_at = 1.hour.ago
      notification.notifiable = student
    end
  when 2
    # 却下通知（未読）
    student.notifications.find_or_create_by(
      notification_type: :approval_rejected,
      title: '申請が却下されました'
    ) do |notification|
      notification.message = '欠勤申請が却下されました。詳細を確認してください。'
      notification.priority = :high
      notification.action_url = '/applications'
      notification.notifiable = student
    end
  when 3
    # 月末締め完了通知（既読）
    student.notifications.find_or_create_by(
      notification_type: :system_announcement,
      title: '月末締めが完了しました'
    ) do |notification|
      notification.message = "#{Date.current.last_month.strftime('%Y年%m月')}の月末締めが完了しました。"
      notification.priority = :normal
      notification.read_at = 2.hours.ago
      notification.notifiable = student
    end
  end

  Rails.logger.debug { "✓ Created notifications for #{student.full_name}" }
end

Rails.logger.debug ''
Rails.logger.debug '================================'
Rails.logger.debug 'All sample data created successfully!'
Rails.logger.debug '================================'
Rails.logger.debug ''
Rails.logger.debug 'Available test accounts:'
Rails.logger.debug '------------------------'
Rails.logger.debug ''
Rails.logger.debug '【システム管理者】'
Rails.logger.debug '  system.admin@example.com'
Rails.logger.debug ''
Rails.logger.debug '【部署管理者】'
Rails.logger.debug '  sales.manager@example.com (営業部)'
Rails.logger.debug '  dev.manager@example.com (開発部)'
Rails.logger.debug '  hr.manager@example.com (人事部)'
Rails.logger.debug ''
Rails.logger.debug '【学生アルバイト】'
Rails.logger.debug '  student1@example.com (田中 太郎 - 営業部)'
Rails.logger.debug '  student2@example.com (佐藤 花子 - 営業部)'
Rails.logger.debug '  student3@example.com (鈴木 次郎 - 開発部)'
Rails.logger.debug '  student4@example.com (高橋 美咲 - 開発部)'
Rails.logger.debug '  student5@example.com (伊藤 健太 - 人事部)'
Rails.logger.debug '  student6@example.com (渡辺 愛 - マーケティング部)'
Rails.logger.debug ''
Rails.logger.debug '【承認待ちユーザー】'
Rails.logger.debug '  pending1@example.com'
Rails.logger.debug '  pending2@example.com'
Rails.logger.debug ''
Rails.logger.debug '【非アクティブユーザー】'
Rails.logger.debug '  inactive@example.com'
Rails.logger.debug ''
Rails.logger.debug '共通パスワード: password123'
Rails.logger.debug ''
Rails.logger.debug 'Sample data includes:'
Rails.logger.debug '- 6名の学生アルバイト（複数部署）'
Rails.logger.debug '- 3名の部署管理者'
Rails.logger.debug '- 先月分の勤怠データ（全学生）'
Rails.logger.debug '- 今月分の勤怠データ（月初〜今日まで）'
Rails.logger.debug '- 週次シフトデータ（今月・来月）'
Rails.logger.debug '- 様々な状態の申請データ（承認待ち、承認済み、却下、キャンセル）'
Rails.logger.debug '- 月末締めデータ（先月・今月）'
Rails.logger.debug '- 通知データ（既読・未読）'
Rails.logger.debug ''
Rails.logger.debug '注意: これらは開発環境専用のアカウントです。'
Rails.logger.debug ''
