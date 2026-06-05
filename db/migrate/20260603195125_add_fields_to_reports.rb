class AddFieldsToReports < ActiveRecord::Migration[8.1]
  def change
    add_column :reports, :total_revenue, :decimal
    add_column :reports, :tickets_count, :integer
  end
end
