class CreateNetworks < ActiveRecord::Migration
  def self.up
    create_table :networks do |t|
      t.string :facebook_id
      t.string :friend_id
      t.integer :degree

      t.timestamps
    end
  end

  def self.down
    drop_table :networks
  end
end
