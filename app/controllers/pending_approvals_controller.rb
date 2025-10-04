# frozen_string_literal: true

class PendingApprovalsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_pending_status

  def index
    @user = current_user
  end

  private

  def ensure_pending_status
    redirect_to root_path unless current_user&.pending?
  end
end
