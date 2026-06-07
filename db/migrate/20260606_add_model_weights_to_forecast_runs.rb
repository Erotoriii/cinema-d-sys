class AddModelWeightsToForecastRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :forecast_runs, :model_weights, :text
  end
end
