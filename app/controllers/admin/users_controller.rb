# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:show, :edit, :update, :approve, :reject]

    def index
      authorize [:admin, User]
      @pending_users = policy_scope([:admin, User]).pending.includes(:department, :roles).order(:created_at)
      @active_users = policy_scope([:admin, User]).active.includes(:department, :roles).order(:first_name, :last_name)

      # 週次労働時間の制限違反チェック
      @weekly_violations = check_all_users_violations(@active_users)
    end

    def show
      authorize [:admin, @user]
    end

    def edit
      authorize [:admin, @user]
      @departments = Department.order(:name)
      @roles = Role.order(:name)
    end

    def update
      authorize [:admin, @user]

      if @user.update(user_params)
        # 権限の更新
        update_user_roles if params[:user][:role_ids]
        redirect_to admin_user_path(@user), notice: 'ユーザー情報が更新されました。'
      else
        @departments = Department.order(:name)
        @roles = Role.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    def approve
      authorize [:admin, @user]

      if @user.approve!
        # デフォルト権限を付与（学生権限）
        @user.add_role(:student) unless @user.roles.exists?
        redirect_to admin_users_path, notice: "#{@user.display_name}さんを承認しました。"
      else
        redirect_to admin_users_path, alert: '承認に失敗しました。'
      end
    end

    def reject
      authorize [:admin, @user]

      if @user.reject!
        redirect_to admin_users_path, notice: "#{@user.display_name}さんの申請を拒否しました。"
      else
        redirect_to admin_users_path, alert: '拒否に失敗しました。'
      end
    end

    def bulk_approve
      authorize [:admin, User]

      user_ids = params[:user_ids] || []
      users = User.pending.where(id: user_ids)

      approved_count = 0
      users.each do |user|
        if user.approve!
          user.add_role(:student) unless user.roles.exists?
          approved_count += 1
        end
      end

      redirect_to admin_users_path, notice: "#{approved_count}人のユーザーを一括承認しました。"
    end

    def bulk_reject
      authorize [:admin, User]

      user_ids = params[:user_ids] || []
      users = User.pending.where(id: user_ids)

      rejected_count = 0
      users.each do |user|
        rejected_count += 1 if user.reject!
      end

      redirect_to admin_users_path, notice: "#{rejected_count}人のユーザーを一括拒否しました。"
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:first_name, :last_name, :department_id, :status)
    end

    def update_user_roles
      role_ids = params[:user][:role_ids].compact_blank
      new_roles = Role.where(id: role_ids)

      # 現在の権限を削除
      @user.user_roles.destroy_all

      # 新しい権限を追加
      new_roles.each do |role|
        @user.add_role(role.name)
      end
    end

    def check_all_users_violations(users)
      violations = []
      start_date = Date.current.beginning_of_week

      users.each do |user|
        # 学生ユーザーのみチェック
        next unless user.has_role?(:student)

        result = Attendance.check_weekly_violations(user, start_date)
        next unless result[:has_violations]

        violations << {
          user: user,
          violations: result[:violations],
          breakdown: result[:breakdown],
        }
      end

      violations
    end
  end
end
