# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    return unless user_signed_in?

    # 今週の労働時間集計と違反チェック
    @week_violations = Attendance.check_weekly_violations(current_user, Date.current.beginning_of_week)
  end
end
