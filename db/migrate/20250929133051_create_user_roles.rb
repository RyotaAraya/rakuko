# frozen_string_literal: true

class CreateUserRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :user_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true

      t.timestamps
    end

    # ユーザーが同じロールを複数持つことを防ぐ
    add_index :user_roles, [:user_id, :role_id], unique: true
  end
end
