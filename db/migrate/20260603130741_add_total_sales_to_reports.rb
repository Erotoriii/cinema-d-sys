class AddTotalSalesToReports < ActiveRecord::Migration[8.1]
  def change
    add_column :reports, :total_sales, :integer
  end
end
