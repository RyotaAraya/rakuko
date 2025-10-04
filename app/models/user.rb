# frozen_string_literal: true

class User < ApplicationRecord
  include AASM

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  if Rails.env.production?
    # 本番環境：Google認証のみ
    devise :rememberable, :omniauthable, omniauth_providers: [:google_oauth2]
  else
    # 開発・ステージング環境：Google認証 + パスワード認証
    devise :database_authenticatable, :rememberable, :omniauthable, omniauth_providers: [:google_oauth2]
  end

  # Enums
  enum :status, { pending: 0, active: 1, inactive: 2 }

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :status, presence: true

  # Associations
  belongs_to :department, optional: true
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles

  # Shift management
  has_many :shifts, dependent: :destroy
  has_many :shift_schedules, through: :shifts

  # Attendance management
  has_many :time_records, dependent: :destroy
  has_many :attendances, dependent: :destroy
  has_many :applications, dependent: :destroy

  # Approval system
  has_many :approvals, foreign_key: 'approver_id', dependent: :destroy
  has_many :approvable_approvals, as: :approvable, class_name: 'Approval', dependent: :destroy

  # Notification system
  has_many :notifications, dependent: :destroy
  has_many :sent_notifications, class_name: 'Notification', foreign_key: 'notifiable_id', dependent: :destroy

  # Month end closings
  has_many :month_end_closings, dependent: :destroy
  has_many :closed_month_end_closings, class_name: 'MonthEndClosing', foreign_key: 'closed_by_id', dependent: :nullify

  # AASM状態管理
  aasm column: :status, enum: true do
    state :pending, initial: true
    state :active
    state :inactive

    event :approve do
      transitions from: :pending, to: :active
    end

    event :reject do
      transitions from: :pending, to: :inactive
    end

    event :activate do
      transitions from: :inactive, to: :active
    end

    event :deactivate do
      transitions from: :active, to: :inactive
    end
  end

  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email

      # 名前を分割してfirst_name, last_nameに設定
      if auth.info.name.present?
        name_parts = auth.info.name.split(' ', 2)
        user.first_name = name_parts[0]
        user.last_name = name_parts[1] if name_parts.length > 1
      else
        user.first_name = auth.info.email.split('@')[0]
      end

      user.encrypted_password = Devise.friendly_token[0, 20]
      user.google_uid = auth.uid
      user.status = :pending # 新規ユーザーは承認待ち状態
    end
  end

  def full_name
    [first_name, last_name].compact.join(' ')
  end

  def display_name
    full_name.presence || email
  end

  # Deviseの認証メソッドをオーバーライド（開発・ステージング環境では制限を緩和）
  def active_for_authentication?
    if Rails.env.production?
      super && active?
    else
      true # 開発・ステージング環境では常にtrue
    end
  end

  def inactive_message
    return :not_approved_yet if Rails.env.production? && !active?

    nil # 開発・ステージング環境ではエラーメッセージなし
  end

  # ====== 権限管理システム（ER図準拠） ======

  # 権限チェックメソッド
  def has_role?(role_name)
    roles.exists?(name: role_name.to_s)
  end

  def add_role(role_name)
    role = Role.find_by(name: role_name.to_s)
    return false unless role

    user_roles.find_or_create_by(role: role)
  end

  def remove_role(role_name)
    role = Role.find_by(name: role_name.to_s)
    return false unless role

    user_roles.where(role: role).destroy_all
  end

  # 権限の表示名リスト
  def role_display_names
    roles.map(&:display_name).join(', ')
  end

  # 個別権限チェック
  def student?
    has_role?(:student)
  end

  def department_manager?
    has_role?(:department_manager)
  end

  def hr_manager?
    has_role?(:hr_manager)
  end

  def system_admin?
    has_role?(:system_admin)
  end

  # 管理者権限チェック（労務担当者 or システム管理者）
  def admin?
    hr_manager? || system_admin?
  end

  # 最高レベル権限の取得（表示用）
  def primary_role_display_name
    return 'システム管理者' if system_admin?
    return '労務担当者' if hr_manager?
    return '部署担当者' if department_manager?
    return 'アルバイト' if student?

    '権限なし'
  end

  # ====== 管理者向けメソッド ======

  # 承認待ちの項目を取得（権限に応じて）
  def pending_approvals_for_role
    Approval.pending_for_approver(self)
  end

  # 未読通知数
  def unread_notifications_count
    notifications.unread.count
  end

  # 今月のシフト
  def current_month_shift
    current_date = Date.current
    shifts.find_by(year: current_date.year, month: current_date.month)
  end

  # 今月の勤怠記録
  def current_month_attendances
    current_date = Date.current
    attendances.for_month(current_date.year, current_date.month)
  end

  # 今月の月末締め処理
  def current_month_closing
    current_date = Date.current
    month_end_closings.find_by(year: current_date.year, month: current_date.month)
  end

  # 承認権限を持つユーザーのスコープ
  scope :department_managers, -> { joins(:roles).where(roles: { name: 'department_manager' }) }
  scope :hr_managers, -> { joins(:roles).where(roles: { name: 'hr_manager' }) }
  scope :system_admins, -> { joins(:roles).where(roles: { name: 'system_admin' }) }
  scope :students, -> { joins(:roles).where(roles: { name: 'student' }) }
end
