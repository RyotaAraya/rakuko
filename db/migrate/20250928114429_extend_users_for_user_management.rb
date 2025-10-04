# frozen_string_literal: true

class ExtendUsersForUserManagement < ActiveRecord::Migration[7.1]
  def change
    # 既存のnameカラムをfirst_name, last_nameに分割
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string

    # ユーザー状態管理（pending, active, inactive）
    add_column :users, :status, :integer, default: 0, null: false
    add_index :users, :status

    # OAuth識別子をgoogle_uidに変更（将来的にuidを削除予定）
    add_column :users, :google_uid, :string
    add_index :users, :google_uid, unique: true

    # 部署との関連付け
    add_column :users, :department_id, :bigint
    add_index :users, :department_id

    # 既存のnameデータをfirst_nameに移行（データが存在する場合）
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE users SET first_name = name WHERE name IS NOT NULL;
        SQL
      end
    end
  end
end
