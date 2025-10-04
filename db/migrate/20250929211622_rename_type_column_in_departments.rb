# frozen_string_literal: true

class RenameTypeColumnInDepartments < ActiveRecord::Migration[7.1]
  def change
    rename_column :departments, :type, :department_type
  end
end
