# frozen_string_literal: true

class ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application, only: [:show, :edit, :update, :destroy, :cancel]

  # GET /applications
  def index
    @applications = current_user.applications.recent
  end

  # GET /applications/:id
  def show; end

  # GET /applications/new
  def new
    @application = current_user.applications.build(
      application_type: :absence,
      application_date: Date.current
    )
  end

  # GET /applications/:id/edit
  def edit; end

  # POST /applications
  def create
    @application = current_user.applications.build(application_params)

    if @application.save
      redirect_to applications_path, notice: '申請を提出しました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /applications/:id
  def update
    if @application.update(application_params)
      # 却下された申請の場合は、更新と同時に再申請
      if @application.can_resubmit? && @application.resubmit!
        redirect_to applications_path, notice: '申請を再提出しました。'
      else
        redirect_to applications_path, notice: '申請を更新しました。'
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /applications/:id
  def destroy
    @application.destroy
    redirect_to applications_path, notice: '申請を削除しました。'
  end

  # POST /applications/:id/cancel
  def cancel
    unless @application.can_cancel?
      redirect_to applications_path, alert: 'この申請は取り消しできません。'
      return
    end

    if @application.cancel!
      redirect_to applications_path, notice: '申請を取り消しました。'
    else
      redirect_to applications_path, alert: '取り消しに失敗しました。'
    end
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
