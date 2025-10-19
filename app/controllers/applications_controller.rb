# frozen_string_literal: true

class ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application, only: [:show, :edit, :update, :destroy]

  # GET /applications
  def index
    @applications = current_user.applications.recent.page(params[:page])
  end

  # GET /applications/:id
  def show; end

  # GET /applications/new
  def new
    @application = current_user.applications.build(
      application_date: Date.current
    )
  end

  # GET /applications/:id/edit
  def edit; end

  # POST /applications
  def create
    @application = current_user.applications.build(application_params)

    if @application.save
      # 申請を提出状態に変更（承認レコード作成）
      if @application.submit
        redirect_to applications_path, notice: '申請を提出しました。'
      else
        redirect_to applications_path, notice: '申請を保存しました。'
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /applications/:id
  def update
    if @application.update(application_params)
      redirect_to @application, notice: '申請を更新しました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /applications/:id
  def destroy
    @application.destroy
    redirect_to applications_path, notice: '申請を削除しました。'
  end

  private

  def set_application
    @application = current_user.applications.find(params[:id])
  end

  def application_params
    params.require(:application).permit(
      :application_type,
      :application_date,
      :reason
    )
  end
end
