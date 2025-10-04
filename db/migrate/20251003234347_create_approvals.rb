# frozen_string_literal: true

class CreateApprovals < ActiveRecord::Migration[7.1]
  def change
    create_table :approvals do |t|
      t.references :approvable, polymorphic: true, null: false
      t.references :approver, null: false, foreign_key: { to_table: :users }
      t.integer :approval_type
      t.integer :status
      t.text :comment
      t.datetime :approved_at

      t.timestamps
    end
  end
end
