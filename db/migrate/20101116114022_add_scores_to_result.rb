class AddScoresToResult < ActiveRecord::Migration
  def self.up
    add_column :results, :winner_score, :integer
    add_column :results, :loser_score, :integer
  end

  def self.down
    remove_column :results, :loser_score
    remove_column :results, :winner_score
  end
end
