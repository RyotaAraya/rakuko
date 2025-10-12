# frozen_string_literal: true

class RemoveLegacyColumnsFromUsers < ActiveRecord::Migration[7.1]
  def change
    # カラムが存在する場合のみ削除
    if column_exists?(:users, :role)
      remove_column :users, :role, :integer
    end

    # 他の不要カラムも削除
    if column_exists?(:users, :name)
      remove_column :users, :name, :string # first_name + last_nameに移行済み
    end
    if column_exists?(:users, :department)
      remove_column :users, :department, :string # department_idに移行済み
    end
    # OAuth用のカラムは保持（必要な可能性があるため）
    # remove_column :users, :provider, :string
    # remove_column :users, :uid, :string
  end
end
