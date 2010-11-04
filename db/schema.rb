# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20101104095829) do

  create_table "profiles", :force => true do |t|
    t.string   "facebook_id"
    t.string   "email"
    t.string   "first_name"
    t.string   "last_name"
    t.datetime "birthday"
    t.string   "location"
    t.string   "hometown"
    t.string   "political"
    t.string   "religion"
    t.string   "relationship_status"
    t.string   "interested_in"
    t.string   "significant_other_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "facebook_id"
    t.string   "full_name"
    t.string   "gender"
    t.integer  "score"
    t.integer  "wins"
    t.integer  "losses"
    t.integer  "win_streak"
    t.integer  "loss_streak"
    t.string   "friends"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
