# frozen_string_literal: true

Rails.application.routes.draw do
  # 承認待ちユーザー画面
  get 'pending_approvals', to: 'pending_approvals#index', as: :pending_approvals_index

  # 管理者機能
  namespace :admin do
    resources :users, only: [:index, :show, :edit, :update] do
      member do
        patch :approve
        patch :reject
      end
      collection do
        post :bulk_approve
        post :bulk_reject
      end
    end
  end

  # 部署管理（管理者権限のみ）
  resources :departments

  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  get 'home/index'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  root 'home#index'
end
