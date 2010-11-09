class AddMiddleNameToProfile < ActiveRecord::Migration
  def self.up
    add_column :profiles, :middle_name, :string
  end

  def self.down
    remove_column :profiles, :middle_name
  end
end
