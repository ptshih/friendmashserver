class RemovePoliticalReligionFromProfile < ActiveRecord::Migration
  def self.up
    remove_column :profiles, :political
    remove_column :profiles, :religion
  end

  def self.down
    add_column :profiles, :religion, :string
    add_column :profiles, :political, :string
  end
end
