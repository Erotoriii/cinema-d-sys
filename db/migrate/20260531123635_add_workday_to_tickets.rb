class AddWorkdayToTickets < ActiveRecord::Migration[8.1]
  def change
    add_reference :tickets, :workday, null: false, foreign_key: true
  end
end
