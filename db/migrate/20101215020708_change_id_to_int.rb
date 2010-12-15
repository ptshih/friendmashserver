class ChangeIdToInt < ActiveRecord::Migration
  def self.up
    change_table :users do |t|
      t.change :id, :bigint
      t.change :facebook_id, :bigint, :default => 0
    end
    change_table :profiles do |t|
      t.change :id, :bigint
      t.change :facebook_id, :bigint, :default => 0
    end
    change_table :tokens do |t|
      t.change :id, :bigint
      t.change :facebook_id, :bigint, :default => 0
    end
    change_table :results do |t|
      t.change :id, :bigint
      t.change :facebook_id, :bigint, :default => 0
      t.change :winner_id, :bigint, :default => 0
      t.change :loser_id, :bigint, :default => 0
    end
    change_table :networks do |t|
      t.change :id, :bigint
      t.change :facebook_id, :bigint, :default => 0
      t.change :friend_id, :bigint, :default => 0
    end
    change_table :employers do |t|
      t.change :id, :bigint
      t.change :facebook_id, :bigint, :default => 0
      t.change :employer_id, :bigint, :default => 0
    end
    change_table :schools do |t|
      t.change :id, :bigint
      t.change :facebook_id, :bigint, :default => 0
      t.change :school_id, :bigint, :default => 0
    end
    change_table :network_caches do |t|
      t.change :id, :bigint
      t.change :facebook_id, :bigint, :default => 0
    end
  end

  def self.down
    change_table :users do |t|
      t.change :id, :integer
      t.change :facebook_id, :string
    end
    change_table :profiles do |t|
      t.change :id, :integer
      t.change :facebook_id, :string
    end
    change_table :tokens do |t|
      t.change :id, :integer
      t.change :facebook_id, :string
    end
    change_table :results do |t|
      t.change :id, :integer
      t.change :facebook_id, :string
      t.change :winner_id, :string
      t.change :loser_id, :string
    end
    change_table :networks do |t|
      t.change :id, :integer
      t.change :facebook_id, :string
      t.change :friend_id, :string
    end
    change_table :employers do |t|
      t.change :id, :integer
      t.change :facebook_id, :string
      t.change :employer_id, :string
    end
    change_table :schools do |t|
      t.change :id, :integer
      t.change :facebook_id, :string
      t.change :school_id, :string
    end
    change_table :network_caches do |t|
      t.change :id, :integer
      t.change :facebook_id, :string
    end
  end
end
