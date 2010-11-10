class CreateResults < ActiveRecord::Migration
  def self.up
    create_table :results do |t|
      t.string :facebook_id
      t.string :winner_id
      t.string :loser_id
      t.boolean :left

      t.timestamps
    end
  end

  def self.down
    drop_table :results
  end
end
