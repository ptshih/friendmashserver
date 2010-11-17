class AddMaxWinLossStreakToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :win_streak_max, :integer, :default => 0
    add_column :users, :loss_streak_max, :integer, :default => 0
    add_column :users, :win_streak_max_network, :integer, :default => 0
    add_column :users, :loss_streak_max_network, :integer, :default => 0
  end

  def self.down
    remove_column :users, :loss_streak_max_network
    remove_column :users, :win_streak_max_network
    remove_column :users, :loss_streak_max
    remove_column :users, :win_streak_max
  end
end
