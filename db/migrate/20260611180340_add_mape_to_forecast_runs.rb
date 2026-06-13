class AddMapeToForecastRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :forecast_runs, :global_mape, :decimal, precision: 5, scale: 2
  end
end
