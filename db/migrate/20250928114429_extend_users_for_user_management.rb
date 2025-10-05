# frozen_string_literal: true

class ExtendUsersForUserManagement < ActiveRecord::Migration[7.1]
  def change
    # カラムが既に存在する場合はスキップ
    unless column_exists?(:users, :first_name)
      add_column :users, :first_name, :string
    end
    unless column_exists?(:users, :last_name)
      add_column :users, :last_name, :string
    end

    # ユーザー状態管理（pending, active, inactive）
    unless column_exists?(:users, :status)
      add_column :users, :status, :integer, default: 0, null: false
      add_index :users, :status
    end

    # OAuth識別子をgoogle_uidに変更（将来的にuidを削除予定）
    unless column_exists?(:users, :google_uid)
      add_column :users, :google_uid, :string
      add_index :users, :google_uid, unique: true
    end

    # 部署との関連付け
    unless column_exists?(:users, :department_id)
      add_column :users, :department_id, :bigint
      add_index :users, :department_id
    end

    # 既存のnameデータをfirst_nameに移行（データが存在する場合）
    reversible do |dir|
      dir.up do
        if column_exists?(:users, :name)
          execute <<-SQL.squish
            UPDATE users SET first_name = name WHERE name IS NOT NULL;
          SQL
        end
      end
    end
  end
end
