class CreateWorkdays < ActiveRecord::Migration[8.1]
  def change
    create_table :workdays do |t|
      t.datetime :start_time
      t.datetime :end_time
      t.references :cinema, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
