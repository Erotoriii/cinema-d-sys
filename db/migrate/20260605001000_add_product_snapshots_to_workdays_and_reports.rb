class AddProductSnapshotsToWorkdaysAndReports < ActiveRecord::Migration[8.1]
  def change
    add_column :workdays, :product_snapshot, :text
    add_column :reports, :product_details, :text
  end
end