# frozen_string_literal: true

class CreateRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :roles do |t|
      t.integer :name, null: false # 0: student, 1: department_manager, 2: hr_manager, 3: system_admin
      t.string :description

      t.timestamps
    end

    add_index :roles, :name, unique: true
  end
end
