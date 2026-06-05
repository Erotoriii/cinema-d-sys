class AddBarSalesTotalToWorkdaysAndDecimalTotalSalesToReports < ActiveRecord::Migration[8.1]
  def up
    add_column :workdays, :bar_sales_total, :decimal, precision: 10, scale: 2, default: 0.0, null: false

    change_column :reports, :total_sales, :decimal, precision: 10, scale: 2, default: 0.0
    execute "UPDATE reports SET total_sales = 0.0 WHERE total_sales IS NULL"
    change_column_null :reports, :total_sales, false, 0.0
  end

  def down
    change_column :reports, :total_sales, :integer, default: 0, null: false
    remove_column :workdays, :bar_sales_total
  end
end