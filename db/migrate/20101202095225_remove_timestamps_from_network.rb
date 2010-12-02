class RemoveTimestampsFromNetwork < ActiveRecord::Migration
  def self.up
    remove_column :networks, :created_at
    remove_column :networks, :updated_at
  end

  def self.down
    add_column :networks, :updated_at, :datetime
    add_column :networks, :created_at, :datetime
  end
end
