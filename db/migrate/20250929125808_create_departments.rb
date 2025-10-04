# frozen_string_literal: true

class CreateDepartments < ActiveRecord::Migration[7.1]
  def change
    create_table :departments do |t|
      t.string :name, null: false
      t.integer :type, default: 0, null: false # 0: general, 1: labor, 2: management
      t.text :description

      t.timestamps
    end

    add_index :departments, :name, unique: true
    add_index :departments, :type
  end
end
