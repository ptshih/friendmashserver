class AddModeToResult < ActiveRecord::Migration
  def self.up
    add_column :results, :mode, :integer
  end

  def self.down
    remove_column :results, :mode
  end
end
