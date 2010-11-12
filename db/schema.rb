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

ActiveRecord::Schema.define(:version => 20101111094804) do

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "employers", :force => true do |t|
    t.string    "facebook_id"
    t.string    "employer_id"
    t.string    "employer_name"
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "networks", :force => true do |t|
    t.string    "facebook_id"
    t.string    "friend_id"
    t.integer   "degree",         :default => 0
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "profiles", :force => true do |t|
    t.string    "facebook_id"
    t.string    "first_name"
    t.string    "last_name"
    t.string    "birthday"
    t.string    "location"
    t.string    "hometown"
    t.string    "relationship_status"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.integer   "votes",              :default => 0
    t.integer   "votes_network",      :default => 0
    t.string    "full_name"
    t.string    "middle_name"
  end

  create_table "results", :force => true do |t|
    t.string    "facebook_id"
    t.string    "winner_id"
    t.string    "loser_id"
    t.boolean   "left",               :default => false
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "schools", :force => true do |t|
    t.string    "facebook_id"
    t.string    "school_id"
    t.string    "school_name"
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "tokens", :force => true do |t|
    t.string    "facebook_id"
    t.string    "access_token"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.string    "udid"
  end

  create_table "users", :force => true do |t|
    t.string    "facebook_id"
    t.string    "gender"
    t.integer   "score",        :default => 1500
    t.integer   "wins",         :default => 0
    t.integer   "losses",       :default => 0
    t.integer   "win_streak",   :default => 0
    t.integer   "loss_streak",  :default => 0
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

end
