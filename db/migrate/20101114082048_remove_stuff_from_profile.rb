class RemoveStuffFromProfile < ActiveRecord::Migration
  def self.up
    remove_column :profiles, :birthday
    remove_column :profiles, :location
    remove_column :profiles, :hometown
    remove_column :profiles, :relationship_status
    remove_column :profiles, :middle_name
  end

  def self.down
    add_column :profiles, :middle_name, :string
    add_column :profiles, :relationship_status, :string
    add_column :profiles, :hometown, :string
    add_column :profiles, :location, :string
    add_column :profiles, :birthday, :string
  end
end
