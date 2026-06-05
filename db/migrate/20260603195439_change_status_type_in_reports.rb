class ChangeStatusTypeInReports < ActiveRecord::Migration[8.1]
  def change
    change_column :reports, :status, :integer, default: 0
  end
end
