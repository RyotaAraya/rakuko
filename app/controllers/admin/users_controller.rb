# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:show, :edit, :update, :approve, :reject]

    def index
      authorize [:admin, User]
      @pending_users = policy_scope([:admin, User]).pending.includes(:department, :roles).order(:created_at)

      # 検索・フィルタリング
      @active_users = filter_active_users
      @departments = Department.order(:name)
      @roles = Role.order(:name)
    end

    def show
      authorize [:admin, @user]
      @departments = Department.order(:name)
      @roles = Role.order(:name)
    end

    def edit
      authorize [:admin, @user]
      @departments = Department.order(:name)
      @roles = Role.order(:name)
    end

    def update
      authorize [:admin, @user]

      if @user.update(user_params)
        # 権限の更新（単一権限）
        update_user_role if params[:user][:role_id]
        redirect_to admin_user_path(@user), notice: 'ユーザー情報が更新されました。'
      else
        @departments = Department.order(:name)
        @roles = Role.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    def approve
      authorize [:admin, @user]

      # 部署選択のバリデーション
      if params[:user][:department_id].blank?
        @departments = Department.order(:name)
        @roles = Role.order(:name)
        flash.now[:alert] = '部署を選択してください。'
        render :show, status: :unprocessable_entity
        return
      end

      # 部署の設定
      @user.department_id = params[:user][:department_id]

      # 契約終了日の設定（アルバイトの場合）
      @user.contract_end_date = params[:user][:contract_end_date] if params[:user][:contract_end_date].present?

      if @user.approve!
        # 権限の設定（単一権限）
        if params[:user][:role_id].present?
          update_user_role
        else
          # デフォルト権限を付与（学生権限）
          @user.add_role(:student) unless @user.roles.exists?
        end

        redirect_to admin_users_path, notice: "#{@user.display_name}さんを承認しました。"
      else
        @departments = Department.order(:name)
        @roles = Role.order(:name)
        flash.now[:alert] = '承認に失敗しました。'
        render :show, status: :unprocessable_entity
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
      params.require(:user).permit(:first_name, :last_name, :department_id, :status, :contract_end_date)
    end

    def update_user_role
      role_id = params[:user][:role_id]
      new_role = Role.find_by(id: role_id)

      return unless new_role

      # 現在の権限を削除
      @user.user_roles.destroy_all

      # 新しい権限を追加（単一）
      @user.add_role(new_role.name)
    end

    def filter_active_users
      users = policy_scope([:admin, User]).active.includes(:department, :roles)
      users = apply_search_filter(users)
      users = apply_department_filter(users)
      users = apply_role_filter(users)
      users.order(:first_name, :last_name)
    end

    def apply_search_filter(users)
      return users if params[:search].blank?

      search_term = "%#{params[:search]}%"
      users.where('first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?',
                  search_term, search_term, search_term)
    end

    def apply_department_filter(users)
      return users if params[:department_id].blank?

      users.where(department_id: params[:department_id])
    end

    def apply_role_filter(users)
      return users if params[:role_id].blank?

      users.joins(:user_roles).where(user_roles: { role_id: params[:role_id] }).distinct
    end
  end
end
