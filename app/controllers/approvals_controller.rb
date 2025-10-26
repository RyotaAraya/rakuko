# frozen_string_literal: true

class ApprovalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_approval, only: [:approve, :reject]

  # GET /approvals
  def index
    authorize Approval

    # フィルタパラメータ
    @filter_type = params[:type] # 'application', 'month_end_closing', または nil（全て）
    @sort_by = params[:sort] || 'created_at' # 'created_at' または 'applicant'

    # Application の承認待ちを取得（approvableもpendingのもののみ）
    application_approvals = if @filter_type.nil? || @filter_type == 'application'
                              Approval
                                .joins(<<-SQL.squish)
          INNER JOIN applications
          ON approvals.approvable_type = 'Application'
          AND approvals.approvable_id = applications.id
                                SQL
                                .where(approval_type: :department, status: :pending)
                                .where(applications: { status: 0 }) # pending
                                .includes(:approvable, :approver)
                            else
                              []
                            end

    # MonthEndClosing の承認待ちを取得（approvableもpending_approvalのもののみ）
    month_end_closing_approvals = if @filter_type.nil? || @filter_type == 'month_end_closing'
                                    Approval
                                      .joins(<<-SQL.squish)
          INNER JOIN month_end_closings
          ON approvals.approvable_type = 'MonthEndClosing'
          AND approvals.approvable_id = month_end_closings.id
                                      SQL
                                      .where(approval_type: :department, status: :pending)
                                      .where(month_end_closings: { status: 0 }) # pending_approval
                                      .includes(:approvable, :approver)
                                  else
                                    []
                                  end

    # Attendance は自動承認なので承認待ち一覧から除外
    all_approvals = application_approvals + month_end_closing_approvals

    # ソート
    @pending_approvals = if @sort_by == 'applicant'
                           all_approvals.sort_by { |a| a.approvable.user.display_name }
                         else
                           all_approvals.sort_by(&:created_at).reverse
                         end
  end

  # POST /approvals/:id/approve
  def approve
    authorize @approval
    process_approval(:approve!, '承認しました。', '承認に失敗しました。')
  end

  # POST /approvals/:id/reject
  def reject
    authorize @approval
    process_approval(:reject!, '却下しました。', '却下に失敗しました。')
  end

  private

  def set_approval
    @approval = Approval.find(params[:id])
  end

  def process_approval(action, success_message, failure_message)
    ActiveRecord::Base.transaction do
      @approval.comment = params[:comment] if params[:comment].present?

      if @approval.public_send(action)
        # AASMのafter_commitが機能しないため、明示的にapprovableの状態を更新
        @approval.approvable.check_and_update_status! if @approval.approvable.respond_to?(:check_and_update_status!)
        redirect_to approvals_path, notice: success_message
      else
        redirect_to approvals_path, alert: failure_message
      end
    end
  rescue AASM::InvalidTransition => e
    action_name = action == :approve! ? '承認' : '却下'
    redirect_to approvals_path, alert: "#{action_name}できません: #{e.message}"
  end
end
