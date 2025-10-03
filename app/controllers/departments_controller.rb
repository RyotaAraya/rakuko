class DepartmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department, only: [:show, :edit, :update, :destroy]

  def index
    authorize Department
    @departments = policy_scope(Department).includes(:users).order(:name)
  end

  def show
    authorize @department
    @users = @department.users.includes(:department).order(:first_name, :last_name)
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
end
