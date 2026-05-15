class AddDimensionsToHalls < ActiveRecord::Migration[8.1]
  def change
    add_column :halls, :rows, :integer
    add_column :halls, :seats_per_row, :integer
  end
end
