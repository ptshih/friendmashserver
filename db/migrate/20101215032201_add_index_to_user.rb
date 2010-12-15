class AddIndexToUser < ActiveRecord::Migration
  def self.up
    add_index :users, :gender
  end

  def self.down
    remove_index :users, :gender
  end
end
