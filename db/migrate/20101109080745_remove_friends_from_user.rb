class RemoveFriendsFromUser < ActiveRecord::Migration
  def self.up
    remove_column :users, :friends
  end

  def self.down
    add_column :users, :friends, :string
  end
end
