class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.decimal :price
      t.integer :amount
      t.integer :sold_amount
      t.references :cinema, null: false, foreign_key: true

      t.timestamps
    end
  end
end
