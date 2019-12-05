class AddAffiliationToSignups < ActiveRecord::Migration[5.0]
  def change
    add_column :signups, :affiliation, :string, :after => :position
  end
end
