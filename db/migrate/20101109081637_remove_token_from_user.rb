class RemoveTokenFromUser < ActiveRecord::Migration
  def self.up
    remove_column :users, :token
  end

  def self.down
    add_column :users, :token, :string
  end
end
