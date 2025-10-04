# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :redirect_pending_users

  # Pundit関連
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def redirect_pending_users
    return unless user_signed_in?
    return if controller_name == 'pending_approvals'
    return if controller_name == 'sessions' # Deviseのsessionsコントローラー全体を除外
    return if controller_name == 'omniauth_callbacks' # OAuthコールバックも除外

    return unless current_user.pending?

    redirect_to pending_approvals_index_path
  end

  def user_not_authorized
    flash[:alert] = 'この操作を実行する権限がありません。'
    redirect_to(request.referer || root_path)
  end
end
