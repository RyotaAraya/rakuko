class RemoveLegacyColumnsFromUsers < ActiveRecord::Migration[7.1]
  def change
    # レガシーroleカラム削除（新しい権限システムに移行）
    remove_column :users, :role, :integer

    # 他の不要カラムも削除
    remove_column :users, :name, :string  # first_name + last_nameに移行済み
    remove_column :users, :department, :string  # department_idに移行済み
    remove_column :users, :provider, :string  # OAuth用、google_uidで代用
    remove_column :users, :uid, :string  # OAuth用、google_uidで代用
  end
end
