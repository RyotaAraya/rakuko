# frozen_string_literal: true

class ApprovalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_approval, only: [:approve, :reject]

  # GET /approvals
  def index
    authorize Approval
    @pending_approvals = Approval.pending_for_approver(current_user)
                                 .includes(:approvable, :approver)
                                 .order(created_at: :desc)
  end

  # POST /approvals/:id/approve
  def approve
    authorize @approval

    if @approval.approve!
      redirect_to approvals_path, notice: '承認しました。'
    else
      redirect_to approvals_path, alert: '承認に失敗しました。'
    end
  rescue AASM::InvalidTransition => e
    redirect_to approvals_path, alert: "承認できません: #{e.message}"
  end

  # POST /approvals/:id/reject
  def reject
    authorize @approval

    if @approval.reject!
      redirect_to approvals_path, notice: '却下しました。'
    else
      redirect_to approvals_path, alert: '却下に失敗しました。'
    end
  rescue AASM::InvalidTransition => e
    redirect_to approvals_path, alert: "却下できません: #{e.message}"
  end

  private

  def set_approval
    @approval = Approval.find(params[:id])
  end
end
