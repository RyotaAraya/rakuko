# frozen_string_literal: true

class AddCanceledStatusToApplications < ActiveRecord::Migration[7.1]
  def change
    # canceled status (3) を追加
    # 既存のenum値: pending: 0, approved: 1, rejected: 2
    # 新しいenum値: canceled: 3
    # データベースには何も変更不要（integer型で3の値を使えるため）
  end
end
