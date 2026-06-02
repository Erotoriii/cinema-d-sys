class AddDomainPrefixToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :domain_prefix, :string
  end
end
