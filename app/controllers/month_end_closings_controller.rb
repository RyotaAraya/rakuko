# frozen_string_literal: true

class MonthEndClosingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_month_end_closing, only: [:show, :submit_for_approval, :approve, :reject, :reopen]

  def index
    authorize MonthEndClosing
    setup_date_params
    load_closings_by_role
    load_pending_approvals if current_user.department_manager?
  end

  def show
    authorize @closing
  end

  def submit_for_approval
    authorize @closing, :submit_for_approval?
    return handle_submit_success if perform_submit

    handle_submit_failure
  end

  def approve
    authorize @closing, :approve?
    return handle_approve_success if perform_approve

    redirect_to month_end_closings_path, alert: '承認できません。'
  end

  def reject
    authorize @closing, :reject?
    return handle_reject_success if perform_reject

    redirect_to month_end_closings_path, alert: '却下できません。'
  end

  def reopen
    authorize @closing
    return handle_reopen_success if perform_reopen

    redirect_to month_end_closings_path, alert: '再開できません。'
  end

  private

  def set_month_end_closing
    @closing = MonthEndClosing.find(params[:id])
  end

  def setup_date_params
    @current_date = Date.current
    @year = params[:year]&.to_i || @current_date.year
    @month = params[:month]&.to_i || @current_date.month
  end

  def load_closings_by_role
    if current_user.student?
      load_student_closings
    elsif current_user.department_manager?
      load_department_manager_closings
    else
      load_system_admin_closings
    end
  end

  def load_student_closings
    @closings = current_user.month_end_closings.recent.limit(12)
    @current_closing = current_user.month_end_closings.find_or_initialize_by(year: @year, month: @month)
    @available_months = current_user.available_months_for_shift # シフト提出と同じ契約期間を使用

    # 契約期間内であれば自動作成
    @current_closing.save if @current_closing.new_record?
  end

  def load_department_manager_closings
    @closings = MonthEndClosing.joins(:user)
                               .where(users: { department_id: current_user.department_id })
                               .recent
                               .includes(:user, :closed_by)
  end

  def load_system_admin_closings
    @closings = MonthEndClosing.recent.includes(:user, :closed_by)
  end

  def load_pending_approvals
    @pending_approvals = MonthEndClosing.joins(:user)
                                        .where(users: { department_id: current_user.department_id })
                                        .pending_approvals
                                        .includes(:user)
  end

  def student_with_current_closing?
    current_user.student? && @current_closing.persisted?
  end

  def perform_submit # rubocop:disable Naming/PredicateMethod
    return false unless @closing.can_submit_for_approval?

    ActiveRecord::Base.transaction do
      @closing.update!(status: :pending_approval)

      # 部署承認のApprovalレコードを作成
      department_manager = @closing.user.department.users
                                   .joins(:user_roles)
                                   .joins('INNER JOIN roles ON user_roles.role_id = roles.id')
                                   .where(roles: { name: 'department_manager' })
                                   .first

      @closing.approvals.create!(
        approval_type: :department,
        status: :pending,
        approver: department_manager
      )
    end

    true
  end

  def handle_submit_success
    redirect_to month_end_closings_path, notice: '承認申請を提出しました。部署担当者の承認をお待ちください。'
  end

  def handle_submit_failure
    redirect_to month_end_closings_path,
                alert: '承認申請できません。すべての勤怠が承認済みであることを確認してください。'
  end

  def perform_approve # rubocop:disable Naming/PredicateMethod
    return false unless @closing.can_approve?

    @closing.update!(status: :closed, closed_by: current_user, closed_at: Time.current)
    true
  end

  def handle_approve_success
    redirect_to month_end_closings_path, notice: '月末締めを承認しました。'
  end

  def perform_reject # rubocop:disable Naming/PredicateMethod
    return false unless @closing.can_reject?

    @closing.update!(status: :open, closed_by: nil, closed_at: nil)
    true
  end

  def handle_reject_success
    redirect_to month_end_closings_path, notice: '月末締めを却下しました。'
  end

  def perform_reopen # rubocop:disable Naming/PredicateMethod
    return false unless @closing.can_reopen?

    @closing.update!(status: :open, closed_by: nil, closed_at: nil)
    true
  end

  def handle_reopen_success
    redirect_to month_end_closings_path, notice: '月末締めを再開しました。'
  end
end
