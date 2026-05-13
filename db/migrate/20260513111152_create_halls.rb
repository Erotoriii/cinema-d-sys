class CreateHalls < ActiveRecord::Migration[8.1]
  def change
    create_table :halls do |t|
      t.string :name
      t.references :cinema, null: false, foreign_key: true

      t.timestamps
    end
  end
end
