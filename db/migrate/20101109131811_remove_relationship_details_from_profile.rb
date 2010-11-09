class RemoveRelationshipDetailsFromProfile < ActiveRecord::Migration
  def self.up
    remove_column :profiles, :interested_in
    remove_column :profiles, :significant_other_id
  end

  def self.down
    add_column :profiles, :significant_other_id, :string
    add_column :profiles, :interested_in, :string
  end
end
