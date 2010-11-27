class RemoveScoreNetworkFromUser < ActiveRecord::Migration
  def self.up
    remove_column :users, :score_network
  end

  def self.down
    add_column :users, :score_network, :integer
  end
end
