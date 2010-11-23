class AddScoreToName < ActiveRecord::Migration
  def self.up
    add_column :names, :score, :float
  end

  def self.down
    remove_column :names, :score
  end
end
