class CreateCinemas < ActiveRecord::Migration[8.1]
  def change
    create_table :cinemas do |t|
      t.string :name
      t.string :address
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end
  end
end
