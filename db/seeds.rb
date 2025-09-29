# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Creating development user accounts..."

# 開発用ユーザーアカウントを作成
development_users = [
  {
    email: "student@example.com",
    first_name: "学生",
    last_name: "太郎",
    role: :student,
    status: :active
  },
  {
    email: "department.manager@example.com",
    first_name: "部署",
    last_name: "管理者",
    role: :department_manager,
    status: :active
  },
  {
    email: "hr.manager@example.com",
    first_name: "労務",
    last_name: "担当者",
    role: :hr_manager,
    status: :active
  },
  {
    email: "system.admin@example.com",
    first_name: "システム",
    last_name: "管理者",
    role: :system_admin,
    status: :active
  },
  {
    email: "pending.user@example.com",
    first_name: "承認待ち",
    last_name: "ユーザー",
    role: :student,
    status: :pending
  }
]

development_users.each do |user_attrs|
  user = User.find_or_initialize_by(email: user_attrs[:email])

  if user.new_record?
    user.assign_attributes(
      first_name: user_attrs[:first_name],
      last_name: user_attrs[:last_name],
      name: "#{user_attrs[:first_name]} #{user_attrs[:last_name]}", # 既存フィールド対応
      role: user_attrs[:role],
      status: user_attrs[:status],
      provider: "development",
      uid: "dev_#{user_attrs[:email].split('@')[0]}",
      google_uid: "dev_#{user_attrs[:email].split('@')[0]}",
      password: "password123", # 開発環境用の簡単なパスワード
      password_confirmation: "password123"
    )

    if user.save
      puts "✓ Created #{user_attrs[:role]} user: #{user.email}"
    else
      puts "✗ Failed to create user: #{user.email} - #{user.errors.full_messages.join(', ')}"
    end
  else
    puts "✓ User already exists: #{user.email} (#{user.role})"
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
