class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.string :status
      t.references :workday, null: false, foreign_key: true

      t.timestamps
    end
  end
end
