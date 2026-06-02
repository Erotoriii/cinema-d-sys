class AddCompanyToMovies < ActiveRecord::Migration[8.1]
  def change
    add_reference :movies, :company, null: true, foreign_key: true
  end
end
