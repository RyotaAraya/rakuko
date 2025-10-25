# frozen_string_literal: true

class DepartmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department, only: [:show, :edit, :update, :destroy]

  def index
    authorize Department
    @departments = policy_scope(Department).includes(:users).order(:name)
  end

  def show
    authorize @department
    @users = @department.users.includes(:roles).order(:first_name, :last_name)
    calculate_department_statistics
  end

  def new
    authorize Department
    @department = Department.new
  end

  def edit
    authorize @department
  end

  def create
    authorize Department
    @department = Department.new(department_params)

    if @department.save
      redirect_to @department, notice: '部署が正常に作成されました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @department
    if @department.update(department_params)
      redirect_to @department, notice: '部署が正常に更新されました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @department
    department_name = @department.name

    if @department.users.exists?
      redirect_to @department, alert: 'ユーザーが所属している部署は削除できません。'
    else
      @department.destroy
      redirect_to departments_path, notice: "部署「#{department_name}」が削除されました。"
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name, :description, :department_type)
  end

  def calculate_department_statistics
    @statistics = {
      total_members: @users.count,
      active_members: count_by_status(:active),
      pending_members: count_by_status(:pending),
      students_count: count_by_role(:student),
      managers_count: count_by_role(:department_manager),
    }
  end

  def count_by_status(status)
    @users.where(status: status).count
  end

  def count_by_role(role_name)
    role = Role.find_by(name: role_name)
    return 0 unless role

    @users.joins(:user_roles).where(user_roles: { role: role }).distinct.count
  end
end
