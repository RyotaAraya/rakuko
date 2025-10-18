# frozen_string_literal: true

class SessionsController < ApplicationController
  # GET /logout - 開発環境での利便性のため
  def logout
    sign_out(current_user) if user_signed_in?
    redirect_to root_path, notice: 'ログアウトしました'
  end
end
