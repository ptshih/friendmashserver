class RemoveEmailFromProfile < ActiveRecord::Migration
  def self.up
    remove_column :profiles, :email
  end

  def self.down
    add_column :profiles, :email, :string
  end
end
