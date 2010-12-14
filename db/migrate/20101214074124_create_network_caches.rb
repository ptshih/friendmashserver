class CreateNetworkCaches < ActiveRecord::Migration
  def self.up
    create_table :network_caches do |t|
      t.string :facebook_id
      t.text :network, :limit => 16777216
      t.timestamp :expires_at
    end
  end

  def self.down
    drop_table :network_caches
  end
end
