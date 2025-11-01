# frozen_string_literal: true

class User < ApplicationRecord
  include AASM

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # 全環境：Google認証 + パスワード認証（デモ用）
  devise :database_authenticatable, :registerable, :rememberable, :omniauthable, omniauth_providers: [:google_oauth2]

  # Enums
  enum :status, { pending: 0, active: 1, inactive: 2 }

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :status, presence: true
  validates :contract_end_date, presence: true, if: :student?
  validate :contract_end_date_after_created_at, if: :student?

  # Associations
  belongs_to :department, optional: true
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles

  # Legacy shift management (removed - now using weekly-centered design)

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

  # Weekly-centered shift management
  has_many :weekly_shifts, dependent: :destroy
  has_many :weeks, through: :weekly_shifts
  has_many :daily_schedules, through: :weekly_shifts
  has_many :monthly_summaries, dependent: :destroy

  # Contract management (self-referential)
  belongs_to :contract_updater, class_name: 'User', foreign_key: 'contract_updated_by_id', optional: true
  has_many :updated_contracts, class_name: 'User', foreign_key: 'contract_updated_by_id', dependent: :nullify

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
    [last_name, first_name].compact.join(' ')
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

  def system_admin?
    has_role?(:system_admin)
  end

  # 管理者権限チェック（システム管理者のみ）
  def admin?
    system_admin?
  end

  # 最高レベル権限の取得（表示用）
  def primary_role_display_name
    return 'システム管理者' if system_admin?
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

  # 今月のシフト（週単位）
  def current_month_shift_summary
    current_date = Date.current
    monthly_summaries.find_by(target_year: current_date.year, target_month: current_date.month)
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

  # ====== 契約期間管理 ======

  # 契約期間内かチェック
  def contract_active?(date = Date.current)
    return false unless contract_start_date && contract_end_date

    date.between?(contract_start_date, contract_end_date)
  end

  # シフト提出可能な月の一覧を取得
  def available_months_for_shift
    return [] unless contract_start_date && contract_end_date

    months = []
    current_date = contract_start_date.beginning_of_month
    end_date = contract_end_date.beginning_of_month

    while current_date <= end_date
      months << { year: current_date.year, month: current_date.month }
      current_date = current_date.next_month
    end

    months
  end

  # 勤怠閲覧可能な月の一覧を取得（契約期間内）
  def available_months_for_attendance
    return [] unless contract_start_date && contract_end_date

    months = []
    current_date = contract_start_date.beginning_of_month
    end_date = contract_end_date.beginning_of_month

    while current_date <= end_date
      months << current_date
      current_date = current_date.next_month
    end

    months
  end

  # 指定した日付が契約期間内かチェック
  def within_contract_period?(date)
    return false unless contract_start_date && contract_end_date

    date.between?(contract_start_date, contract_end_date)
  end

  # 指定月が編集可能かチェック
  def can_edit_shift_for_month?(year, month)
    target_date = Date.new(year, month, 1)
    today = Date.current

    # 1. 契約期間内チェック
    return false unless contract_active?(target_date)

    # 2. 過去月は編集不可、当月・来月以降は編集可能
    # （学業優先のため、当月も柔軟に変更可能）
    target_date >= today.beginning_of_month
  end

  # 締切日を過ぎているかチェック（25日締切）
  def past_deadline_for_month?(year, month)
    target_date = Date.new(year, month, 1)
    today = Date.current

    # 翌月分かつ25日を過ぎている
    target_date == (today + 1.month).beginning_of_month && today.day > 25
  end

  # 承認権限を持つユーザーのスコープ
  scope :department_managers, -> { joins(:roles).where(roles: { name: 'department_manager' }) }
  scope :system_admins, -> { joins(:roles).where(roles: { name: 'system_admin' }) }
  scope :students, -> { joins(:roles).where(roles: { name: 'student' }) }

  # Callbacks
  before_create :set_default_contract_end_date, if: :student?

  private

  # 契約終了日が契約開始日（作成日時）より後かチェック
  def contract_end_date_after_created_at
    return unless contract_end_date && created_at

    return unless contract_end_date <= created_at.to_date

    errors.add(:contract_end_date, 'は契約開始日より後の日付を設定してください')
  end

  # デフォルトの契約終了日を設定（作成日の6ヶ月後）
  def set_default_contract_end_date
    self.contract_end_date ||= (created_at || Time.current).to_date + 6.months
  end
end
