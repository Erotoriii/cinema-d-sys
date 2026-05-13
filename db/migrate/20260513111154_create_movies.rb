class CreateMovies < ActiveRecord::Migration[8.1]
  def change
    create_table :movies do |t|
      t.string :title
      t.integer :duration
      t.text :description
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :movies, :deleted_at
  end
end
