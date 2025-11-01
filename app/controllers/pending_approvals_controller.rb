# frozen_string_literal: true

class PendingApprovalsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_pending_status

  def index
    @user = current_user
  end

  private

  def ensure_pending_status
    # pendingまたはinactiveユーザーのみアクセス可能
    redirect_to root_path unless current_user&.pending? || current_user&.inactive?
  end
end
