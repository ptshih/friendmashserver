class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string :facebook_id
      t.string :full_name
      t.string :gender
      t.integer :score
      t.integer :wins
      t.integer :losses
      t.integer :win_streak
      t.integer :loss_streak
      t.string :friends

      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end
