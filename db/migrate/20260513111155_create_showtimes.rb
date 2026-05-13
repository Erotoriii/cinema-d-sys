class CreateShowtimes < ActiveRecord::Migration[8.1]
  def change
    create_table :showtimes do |t|
      t.datetime :start_time
      t.decimal :price
      t.references :movie, null: false, foreign_key: true
      t.references :hall, null: false, foreign_key: true

      t.timestamps
    end
  end
end
