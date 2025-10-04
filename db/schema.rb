# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_10_03_235416) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "application_type"
    t.date "application_date"
    t.time "start_time"
    t.time "end_time"
    t.text "reason"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_applications_on_user_id"
  end

  create_table "approvals", force: :cascade do |t|
    t.string "approvable_type", null: false
    t.bigint "approvable_id", null: false
    t.bigint "approver_id", null: false
    t.integer "approval_type"
    t.integer "status"
    t.text "comment"
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approvable_type", "approvable_id"], name: "index_approvals_on_approvable"
    t.index ["approver_id"], name: "index_approvals_on_approver_id"
  end

  create_table "attendances", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "date"
    t.decimal "actual_hours"
    t.integer "total_break_time"
    t.boolean "is_auto_generated"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_attendances_on_user_id"
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.integer "department_type", default: 0, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_type"], name: "index_departments_on_department_type"
    t.index ["name"], name: "index_departments_on_name", unique: true
  end

  create_table "month_end_closings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "year"
    t.integer "month"
    t.integer "status"
    t.decimal "total_work_hours"
    t.integer "total_work_days"
    t.decimal "overtime_hours"
    t.datetime "closed_at"
    t.bigint "closed_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["closed_by_id"], name: "index_month_end_closings_on_closed_by_id"
    t.index ["user_id"], name: "index_month_end_closings_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "notifiable_type", null: false
    t.bigint "notifiable_id", null: false
    t.bigint "user_id", null: false
    t.integer "notification_type"
    t.string "title"
    t.text "message"
    t.datetime "read_at"
    t.string "action_url"
    t.integer "priority"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.integer "name", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "shift_requests", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_shift_requests_on_status"
    t.index ["user_id", "start_date"], name: "index_shift_requests_on_user_id_and_start_date"
    t.index ["user_id"], name: "index_shift_requests_on_user_id"
  end

  create_table "shift_schedules", force: :cascade do |t|
    t.bigint "shift_id", null: false
    t.date "date"
    t.time "company_start_time"
    t.time "company_end_time"
    t.time "part_time_start_time"
    t.time "part_time_end_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_working"
    t.index ["shift_id"], name: "index_shift_schedules_on_shift_id"
  end

  create_table "shifts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "year"
    t.integer "month"
    t.integer "status"
    t.text "violation_warnings"
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_shifts_on_user_id"
  end

  create_table "time_records", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "date"
    t.integer "record_type"
    t.datetime "recorded_at"
    t.integer "break_sequence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_time_records_on_user_id"
  end

  create_table "user_roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.integer "status", default: 0, null: false
    t.string "google_uid"
    t.bigint "department_id"
    t.index ["department_id"], name: "index_users_on_department_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["status"], name: "index_users_on_status"
  end

  add_foreign_key "applications", "users"
  add_foreign_key "approvals", "users", column: "approver_id"
  add_foreign_key "attendances", "users"
  add_foreign_key "month_end_closings", "users"
  add_foreign_key "month_end_closings", "users", column: "closed_by_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "shift_requests", "users"
  add_foreign_key "shift_schedules", "shifts"
  add_foreign_key "shifts", "users"
  add_foreign_key "time_records", "users"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
end
