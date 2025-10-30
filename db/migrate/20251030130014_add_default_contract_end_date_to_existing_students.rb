# frozen_string_literal: true

class AddDefaultContractEndDateToExistingStudents < ActiveRecord::Migration[7.1]
  def up
    # アルバイト権限を持つユーザーで契約終了日が未設定のユーザーに
    # 作成日の6ヶ月後をデフォルト値として設定
    student_role = Role.find_by(name: 'student')
    return unless student_role

    User.joins(:user_roles)
        .where(user_roles: { role_id: student_role.id })
        .where(contract_end_date: nil)
        .find_each do |user|
      user.update_column(:contract_end_date, user.created_at.to_date + 6.months)
    end
  end

  def down
    # ロールバック時は何もしない
  end
end
