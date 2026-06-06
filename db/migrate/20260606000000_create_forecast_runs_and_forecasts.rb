class CreateForecastRunsAndForecasts < ActiveRecord::Migration[7.0]
  def change
    create_table :forecast_runs do |t|
      t.datetime :run_at, null: false
      t.integer :horizon_days, null: false, default: 1
      t.string :model
      t.text :params

      t.timestamps
    end

    create_table :forecasts do |t|
      t.references :forecast_run, null: false, foreign_key: true
      t.references :hall, null: false, foreign_key: { to_table: :halls }
      t.datetime :showtime_at, null: false
      t.decimal :predicted_tickets, precision: 10, scale: 2
      t.decimal :predicted_fill_pct, precision: 5, scale: 2

      t.timestamps
    end
  end
end
