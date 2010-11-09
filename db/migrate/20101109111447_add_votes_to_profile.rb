class AddVotesToProfile < ActiveRecord::Migration
  def self.up
    add_column :profiles, :votes, :integer
    add_column :profiles, :votes_network, :integer
  end

  def self.down
    remove_column :profiles, :votes_network
    remove_column :profiles, :votes
  end
end
