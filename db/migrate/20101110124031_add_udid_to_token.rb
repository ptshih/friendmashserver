class AddUdidToToken < ActiveRecord::Migration
  def self.up
    add_column :tokens, :udid, :string
  end

  def self.down
    remove_column :tokens, :udid
  end
end
