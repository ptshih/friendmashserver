class CreateProfiles < ActiveRecord::Migration
  def self.up
    create_table :profiles do |t|
      t.string :facebook_id
      t.string :email
      t.string :first_name
      t.string :last_name
      t.timestamp :birthday
      t.string :location
      t.string :hometown
      t.string :political
      t.string :religion
      t.string :relationship_status
      t.string :interested_in
      t.string :significant_other_id

      t.timestamps
    end
  end

  def self.down
    drop_table :profiles
  end
end
