class CreateSeats < ActiveRecord::Migration[8.1]
  def change
    create_table :seats do |t|
      t.integer :row
      t.integer :number
      t.string :status
      t.references :hall, null: false, foreign_key: true

      t.timestamps
    end
  end
end
