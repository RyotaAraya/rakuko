# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true
  belongs_to :user

  # Enums
  enum :notification_type, {
    approval_request: 0,
    approval_approved: 1,
    approval_rejected: 2,
    shift_reminder: 3,
    attendance_reminder: 4,
    system_announcement: 5,
  }

  enum :priority, {
    low: 0,
    normal: 1,
    high: 2,
    urgent: 3,
  }

  # Validations
  validates :notification_type, presence: true
  validates :title, presence: true, length: { maximum: 200 }
  validates :message, presence: true, length: { maximum: 1000 }
  validates :priority, presence: true
  validates :action_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_priority, -> { order(priority: :desc, created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }

  # Helper methods
  def read?
    read_at.present?
  end

  def unread?
    read_at.nil?
  end

  def mark_as_read!
    update!(read_at: Time.current) if unread?
  end

  def mark_as_unread!
    update!(read_at: nil) if read?
  end

  def notification_type_display_name
    {
      'approval_request' => '承認依頼',
      'approval_approved' => '承認完了',
      'approval_rejected' => '承認却下',
      'shift_reminder' => 'シフト提出リマインダー',
      'attendance_reminder' => '勤怠入力リマインダー',
      'system_announcement' => 'システムお知らせ',
    }[notification_type]
  end

  def priority_display_name
    {
      'low' => '低',
      'normal' => '通常',
      'high' => '高',
      'urgent' => '緊急',
    }[priority]
  end

  def priority_badge_class
    {
      'low' => 'badge-secondary',
      'normal' => 'badge-primary',
      'high' => 'badge-warning',
      'urgent' => 'badge-error',
    }[priority]
  end

  def formatted_created_at
    created_at.strftime('%Y/%m/%d %H:%M')
  end

  def time_ago
    time_diff = Time.current - created_at

    case time_diff
    when 0..59
      '1分以内'
    when 60..3599
      "#{(time_diff / 60).to_i}分前"
    when 3600..86_399
      "#{(time_diff / 3600).to_i}時間前"
    else
      "#{(time_diff / 86_400).to_i}日前"
    end
  end

  # Class methods
  def self.create_approval_request(approval)
    approver = case approval.approval_type
               when 'department_approval'
                 User.department_managers.first
               when 'labor_approval'
                 User.hr_managers.first
               end

    return unless approver

    create!(
      notifiable: approval,
      user: approver,
      notification_type: :approval_request,
      title: "#{approval.approval_type_display_name}の依頼",
      message: "#{approval.approvable_summary}の承認依頼があります。",
      priority: :normal,
      action_url: '/pending_approvals'
    )
  end

  def self.create_approval_result(approval)
    return unless approval.approvable.respond_to?(:user)

    notification_type = approval.approved? ? :approval_approved : :approval_rejected
    title = approval.approved? ? '承認完了' : '承認却下'
    message = "#{approval.approvable_summary}が#{approval.status_display_name}されました。"

    message += "\n理由: #{approval.comment}" if approval.rejected? && approval.comment.present?

    create!(
      notifiable: approval,
      user: approval.approvable.user,
      notification_type: notification_type,
      title: title,
      message: message,
      priority: approval.rejected? ? :high : :normal
    )
  end

  def self.create_shift_reminder(user)
    current_date = Date.current
    next_month = current_date.next_month

    create!(
      notifiable: user,
      user: user,
      notification_type: :shift_reminder,
      title: 'シフト提出リマインダー',
      message: "#{next_month.strftime('%Y年%m月')}のシフトを提出してください。",
      priority: :normal,
      action_url: '/shifts/new'
    )
  end

  def self.create_attendance_reminder(user, date)
    create!(
      notifiable: user,
      user: user,
      notification_type: :attendance_reminder,
      title: '勤怠入力リマインダー',
      message: "#{date.strftime('%Y/%m/%d')}の勤怠入力を忘れずに行ってください。",
      priority: :normal,
      action_url: '/attendances'
    )
  end

  def self.create_system_announcement(title, message, priority = :normal)
    User.find_each do |user|
      create!(
        notifiable: user,
        user: user,
        notification_type: :system_announcement,
        title: title,
        message: message,
        priority: priority
      )
    end
  end

  def self.unread_count_for_user(user)
    unread.for_user(user).count
  end

  def self.mark_all_as_read_for_user(user)
    unread.for_user(user).update_all(read_at: Time.current)
  end
end
