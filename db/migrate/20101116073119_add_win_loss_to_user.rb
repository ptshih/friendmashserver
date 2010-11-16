class AddWinLossToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :wins_network, :integer, :default => 0
    add_column :users, :losses_network, :integer, :default => 0
    add_column :users, :win_streak_network, :integer, :default => 0
    add_column :users, :loss_streak_network, :integer, :default => 0
  end

  def self.down
    remove_column :users, :loss_streak_network
    remove_column :users, :win_streak_network
    remove_column :users, :losses_network
    remove_column :users, :wins_network
  end
end
