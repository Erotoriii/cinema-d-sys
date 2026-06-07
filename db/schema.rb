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

ActiveRecord::Schema[8.1].define(version: 2026_06_06_120000) do
  create_table "cinemas", force: :cascade do |t|
    t.string "address"
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_cinemas_on_company_id"
  end

  create_table "companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "domain_prefix"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "forecast_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "horizon_days", default: 1, null: false
    t.string "model"
    t.text "model_weights"
    t.text "params"
    t.datetime "run_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "forecasts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "forecast_run_id", null: false
    t.integer "hall_id", null: false
    t.integer "movie_id"
    t.decimal "predicted_fill_pct", precision: 5, scale: 2
    t.decimal "predicted_tickets", precision: 10, scale: 2
    t.datetime "showtime_at", null: false
    t.integer "showtime_id"
    t.datetime "updated_at", null: false
    t.index ["forecast_run_id"], name: "index_forecasts_on_forecast_run_id"
    t.index ["hall_id"], name: "index_forecasts_on_hall_id"
    t.index ["movie_id"], name: "index_forecasts_on_movie_id"
    t.index ["showtime_id"], name: "index_forecasts_on_showtime_id"
  end

  create_table "halls", force: :cascade do |t|
    t.integer "cinema_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "rows"
    t.integer "seats_per_row"
    t.datetime "updated_at", null: false
    t.index ["cinema_id"], name: "index_halls_on_cinema_id"
  end

  create_table "movies", force: :cascade do |t|
    t.integer "company_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.integer "duration"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_movies_on_company_id"
    t.index ["deleted_at"], name: "index_movies_on_deleted_at"
  end

  create_table "products", force: :cascade do |t|
    t.integer "amount"
    t.integer "cinema_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.decimal "price"
    t.integer "sold_amount"
    t.datetime "updated_at", null: false
    t.index ["cinema_id"], name: "index_products_on_cinema_id"
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "product_details"
    t.integer "status", default: 0
    t.integer "tickets_count"
    t.decimal "total_revenue"
    t.decimal "total_sales", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.integer "workday_id", null: false
    t.index ["workday_id"], name: "index_reports_on_workday_id"
  end

  create_table "seats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "hall_id", null: false
    t.integer "number"
    t.integer "row"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["hall_id"], name: "index_seats_on_hall_id"
  end

  create_table "showtimes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "hall_id", null: false
    t.integer "movie_id", null: false
    t.decimal "price"
    t.datetime "start_time"
    t.datetime "updated_at", null: false
    t.index ["hall_id"], name: "index_showtimes_on_hall_id"
    t.index ["movie_id"], name: "index_showtimes_on_movie_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tickets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "seat_id", null: false
    t.integer "showtime_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "workday_id", null: false
    t.index ["seat_id"], name: "index_tickets_on_seat_id"
    t.index ["showtime_id"], name: "index_tickets_on_showtime_id"
    t.index ["workday_id"], name: "index_tickets_on_workday_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "cinema_id"
    t.integer "company_id"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["cinema_id"], name: "index_users_on_cinema_id"
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workdays", force: :cascade do |t|
    t.decimal "bar_sales_total", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "cinema_id", null: false
    t.datetime "created_at", null: false
    t.datetime "end_time"
    t.text "product_snapshot"
    t.datetime "start_time"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["cinema_id"], name: "index_workdays_on_cinema_id"
    t.index ["user_id"], name: "index_workdays_on_user_id"
  end

  add_foreign_key "cinemas", "companies"
  add_foreign_key "forecasts", "forecast_runs"
  add_foreign_key "forecasts", "halls"
  add_foreign_key "forecasts", "movies"
  add_foreign_key "forecasts", "showtimes"
  add_foreign_key "halls", "cinemas"
  add_foreign_key "movies", "companies"
  add_foreign_key "products", "cinemas"
  add_foreign_key "reports", "workdays"
  add_foreign_key "seats", "halls"
  add_foreign_key "showtimes", "halls"
  add_foreign_key "showtimes", "movies"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tickets", "seats"
  add_foreign_key "tickets", "showtimes"
  add_foreign_key "tickets", "workdays"
  add_foreign_key "users", "cinemas", on_delete: :nullify
  add_foreign_key "users", "companies"
  add_foreign_key "workdays", "cinemas"
  add_foreign_key "workdays", "users"
end
