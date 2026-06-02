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

ActiveRecord::Schema[8.1].define(version: 2026_05_31_123635) do
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
    t.string "name"
    t.datetime "updated_at", null: false
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
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.integer "duration"
    t.string "title"
    t.datetime "updated_at", null: false
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
    t.string "status"
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workdays", force: :cascade do |t|
    t.integer "cinema_id", null: false
    t.datetime "created_at", null: false
    t.datetime "end_time"
    t.datetime "start_time"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["cinema_id"], name: "index_workdays_on_cinema_id"
    t.index ["user_id"], name: "index_workdays_on_user_id"
  end

  add_foreign_key "cinemas", "companies"
  add_foreign_key "halls", "cinemas"
  add_foreign_key "products", "cinemas"
  add_foreign_key "reports", "workdays"
  add_foreign_key "seats", "halls"
  add_foreign_key "showtimes", "halls"
  add_foreign_key "showtimes", "movies"
  add_foreign_key "tickets", "seats"
  add_foreign_key "tickets", "showtimes"
  add_foreign_key "tickets", "workdays"
  add_foreign_key "workdays", "cinemas"
  add_foreign_key "workdays", "users"
end
