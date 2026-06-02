class AddCinemaForeignKeyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :users, :cinemas, column: :cinema_id, on_delete: :nullify
  end
end
