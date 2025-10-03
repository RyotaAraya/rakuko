class Admin::UserPolicy < ApplicationPolicy
  def index?
    user.admin? # 労務担当者 or システム管理者のみ
  end

  def show?
    user.admin?
  end

  def edit?
    user.admin?
  end

  def update?
    user.admin?
  end

  def approve?
    user.admin?
  end

  def reject?
    user.admin?
  end

  def bulk_approve?
    user.admin?
  end

  def bulk_reject?
    user.admin?
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
