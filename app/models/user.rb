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
  enum status: { pending: 0, active: 1, inactive: 2 }
  enum role: { student: 0, department_manager: 1, hr_manager: 2, system_admin: 3 }

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :status, presence: true

  # Associations
  belongs_to :department, optional: true

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

      # 既存のnameフィールドも設定（後で削除予定）
      user.name = auth.info.name || auth.info.email

      # 名前を分割してfirst_name, last_nameに設定
      if auth.info.name.present?
        name_parts = auth.info.name.split(' ', 2)
        user.first_name = name_parts[0]
        user.last_name = name_parts[1] if name_parts.length > 1
      else
        user.first_name = auth.info.email.split('@')[0]
      end

      user.encrypted_password = Devise.friendly_token[0, 20]
      user.provider = auth.provider
      user.uid = auth.uid
      user.google_uid = auth.uid
      user.status = :pending # 新規ユーザーは承認待ち状態
    end
  end

  def full_name
    [first_name, last_name].compact.join(' ')
  end

  def display_name
    full_name.present? ? full_name : email
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
    if Rails.env.production? && !active?
      :not_approved_yet
    else
      nil # 開発・ステージング環境ではエラーメッセージなし
    end
  end
end
