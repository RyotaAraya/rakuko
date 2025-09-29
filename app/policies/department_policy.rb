class DepartmentPolicy < ApplicationPolicy
  def index?
    user.admin? # 労務担当者 or システム管理者のみ
  end

  def show?
    user.admin?
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