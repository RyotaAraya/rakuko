# frozen_string_literal: true

class AddContractFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :contract_start_date, :date, comment: '契約開始日'
    add_column :users, :contract_end_date, :date, comment: '契約終了日'
    add_column :users, :contract_updated_at, :datetime, comment: '契約更新日時'
    add_column :users, :contract_updated_by_id, :bigint, comment: '契約更新者ID'

    add_foreign_key :users, :users, column: :contract_updated_by_id
    add_index :users, :contract_updated_by_id
    add_index :users, :contract_start_date
    add_index :users, :contract_end_date
  end
end
