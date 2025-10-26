# frozen_string_literal: true

class ApprovalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_approval, only: [:approve, :reject]

  # GET /approvals
  def index
    authorize Approval
    # Application の承認待ちを取得（approvableもpendingのもののみ）
    application_approvals = Approval
                            .joins(<<-SQL.squish)
        INNER JOIN applications
        ON approvals.approvable_type = 'Application'
        AND approvals.approvable_id = applications.id
                            SQL
                            .where(approval_type: :department, status: :pending)
                            .where(applications: { status: 0 }) # pending
                            .includes(:approvable, :approver)

    # MonthEndClosing の承認待ちを取得（approvableもpending_approvalのもののみ）
    month_end_closing_approvals = Approval
                                  .joins(<<-SQL.squish)
        INNER JOIN month_end_closings
        ON approvals.approvable_type = 'MonthEndClosing'
        AND approvals.approvable_id = month_end_closings.id
                                  SQL
                                  .where(approval_type: :department, status: :pending)
                                  .where(month_end_closings: { status: 0 }) # pending_approval
                                  .includes(:approvable, :approver)

    # Attendance は自動承認なので承認待ち一覧から除外
    @pending_approvals = (application_approvals + month_end_closing_approvals)
                         .sort_by(&:created_at).reverse
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
