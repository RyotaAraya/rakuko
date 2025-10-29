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

  # 各種申請（欠勤・遅刻・早退）
  resources :applications do
    member do
      post :cancel
    end
  end

  # 承認管理（部署担当者用）
  resources :approvals, only: [:index] do
    member do
      post :approve
      post :reject
    end
  end

  # 月末締め処理
  resources :month_end_closings, only: [:index, :show] do
    member do
      post :submit_for_approval
      post :approve
      post :reject
      post :reopen
    end
  end

  # シフト希望提出
  resources :shift_requests, only: [:new, :create, :update]

  # ユーザー個別のシフト閲覧（部署担当者・システム管理者用）
  resources :users, only: [] do
    member do
      get :shift_requests
    end
  end

  # 勤怠登録
  resources :attendances, only: [:index, :show, :new, :create] do
    collection do
      get :today
      get :weekly
    end
  end

  # 打刻API
  resources :time_records, only: [:create] do
    collection do
      post :clock_in
      post :clock_out
      post :break_start
      post :break_end
      get :today
    end
  end

  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  # 開発環境での利便性のため、GETでもログアウト可能にする
  get '/users/sign_out', to: 'sessions#logout' unless Rails.env.production?
  get '/logout', to: 'sessions#logout' unless Rails.env.production?

  get 'home/index'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  root 'home#index'
end
