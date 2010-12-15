class ChangeGenderToEnum < ActiveRecord::Migration
  def self.up
    change_table :users do |t|
      t.change :gender, "enum('male','female')"
    end
  end

  def self.down
    change_table :users do |t|
      t.change :gender, :string
    end
  end
end
