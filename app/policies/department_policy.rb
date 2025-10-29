# frozen_string_literal: true

class DepartmentPolicy < ApplicationPolicy
  def index?
    user.admin? # システム管理者のみ
  end

  def show?
    # システム管理者は全部署を閲覧可能
    # 部署担当者は自分の部署のみ閲覧可能
    user.system_admin? || (user.department_manager? && user.department_id == record.id)
  end

  def new?
    user.admin?
  end

  def create?
    user.admin?
  end

  def edit?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy?
    user.system_admin? # システム管理者のみ
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.none
      end
    end
  end
end
