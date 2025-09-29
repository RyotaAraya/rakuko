class ApplicationController < ActionController::Base
  before_action :redirect_pending_users

  private

  def redirect_pending_users
    return unless user_signed_in?
    return if controller_name == 'pending_approvals'
    return if controller_name == 'sessions' # Deviseのsessionsコントローラー全体を除外
    return if controller_name == 'omniauth_callbacks' # OAuthコールバックも除外

    if current_user.pending?
      redirect_to pending_approvals_index_path
    end
  end
end
