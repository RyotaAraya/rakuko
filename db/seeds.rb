# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Setting up roles and departments..."

# 1. 初期ロールの作成（ER図準拠）
puts "Creating roles..."
Role.seed_data.each do |role_data|
  role = Role.find_or_create_by(name: role_data[:name]) do |r|
    r.description = role_data[:description]
  end
  puts "✓ Role: #{role.display_name} (#{role.name})"
end

# 2. 初期部署の作成
puts "Creating departments..."
initial_departments = [
  { name: "情報システム部", department_type: :management, description: "システム管理・運用を担当" },
  { name: "人事労務部", department_type: :labor, description: "労務管理・人事業務を担当" },
  { name: "営業部", department_type: :general, description: "営業活動を担当する一般事業部" },
  { name: "開発部", department_type: :general, description: "プロダクト開発を担当する一般事業部" }
]

initial_departments.each do |dept_data|
  dept = Department.find_or_create_by(name: dept_data[:name]) do |d|
    d.department_type = dept_data[:department_type]
    d.description = dept_data[:description]
  end
  puts "✓ Department: #{dept.name} (#{dept.type_display_name})"
end

puts "Creating development user accounts..."

# 3. 開発用ユーザーアカウントを作成
development_users = [
  {
    email: "student@example.com",
    first_name: "学生",
    last_name: "太郎",
    roles: [:student],
    status: :active,
    department: "営業部"
  },
  {
    email: "department.manager@example.com",
    first_name: "部署",
    last_name: "管理者",
    roles: [:department_manager],
    status: :active,
    department: "営業部"
  },
  {
    email: "hr.manager@example.com",
    first_name: "労務",
    last_name: "担当者",
    roles: [:hr_manager],
    status: :active,
    department: "人事労務部"
  },
  {
    email: "system.admin@example.com",
    first_name: "システム",
    last_name: "管理者",
    roles: [:system_admin],
    status: :active,
    department: "情報システム部"
  },
  {
    email: "multi.role@example.com",
    first_name: "複数権限",
    last_name: "ユーザー",
    roles: [:department_manager, :hr_manager],
    status: :active,
    department: "人事労務部"
  },
  {
    email: "pending.user@example.com",
    first_name: "承認待ち",
    last_name: "ユーザー",
    roles: [], # 承認待ちは権限なし
    status: :pending,
    department: nil
  }
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
      password: "password123",
      password_confirmation: "password123"
    )

    if user.save
      # 新しい権限システムで権限を設定
      user_attrs[:roles].each do |role_name|
        user.add_role(role_name)
      end
      puts "✓ Created user: #{user.email} (#{user_attrs[:roles].join(', ')})"
    else
      puts "✗ Failed to create user: #{user.email} - #{user.errors.full_messages.join(', ')}"
    end
  else
    puts "✓ User already exists: #{user.email} (#{user.role_display_names})"
  end
end

puts "Development user accounts setup complete!"
puts ""
puts "Available test accounts:"
puts "========================"
puts "学生ユーザー: student@example.com"
puts "部署管理者: department.manager@example.com"
puts "労務担当者: hr.manager@example.com"
puts "システム管理者: system.admin@example.com"
puts "承認待ちユーザー: pending.user@example.com"
puts ""
puts "共通パスワード: password123"
puts "ログインURL: /users/sign_in"
puts ""
puts "注意: これらは開発環境専用のアカウントです。"
