# frozen_string_literal: true

class Role < ApplicationRecord
  # Enums - ER図準拠の権限名
  enum :name, { student: 0, department_manager: 1, hr_manager: 2, system_admin: 3 }

  # Associations
  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :description, presence: true

  # Scopes
  scope :management_roles, -> { where(name: [:department_manager, :hr_manager, :system_admin]) }

  def display_name
    {
      'student' => 'アルバイト',
      'department_manager' => '部署担当者',
      'hr_manager' => '労務担当者',
      'system_admin' => 'システム管理者',
    }[name]
  end

  def self.seed_data
    [
      { name: 'student', description: '一般学生ユーザ - シフト希望提出、勤怠登録、各種申請' },
      { name: 'department_manager', description: '部署内アルバイト管理 - 自部署アルバイトの承認・管理' },
      { name: 'hr_manager', description: '全社労務管理 - 全部署の労務観点での承認・制約チェック' },
      { name: 'system_admin', description: 'システム全体管理 - ユーザ承認、部署管理、システム設定' },
    ]
  end
end
