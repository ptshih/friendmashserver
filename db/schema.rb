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

ActiveRecord::Schema.define(:version => 20101215032201) do

  create_table "calendar", :primary_key => "dt", :force => true do |t|
  end

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
    t.integer  "facebook_id",   :limit => 8, :default => 0
    t.integer  "employer_id",   :limit => 8, :default => 0
    t.string   "employer_name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "names", :force => true do |t|
    t.string "name"
    t.string "gender"
    t.float  "score"
  end

  create_table "network_caches", :id => false, :force => true do |t|
    t.integer  "id",          :limit => 8,                         :null => false
    t.integer  "facebook_id", :limit => 8,          :default => 0, :null => false
    t.text     "network",     :limit => 2147483647
    t.datetime "expires_at"
  end

  create_table "networks", :force => true do |t|
    t.integer "facebook_id", :limit => 8, :default => 0
    t.integer "friend_id",   :limit => 8, :default => 0
    t.integer "degree",                   :default => 0
  end

  add_index "networks", ["facebook_id"], :name => "idx_networks_facebook_id"
  add_index "networks", ["friend_id"], :name => "idx_networks_friend_id"

  create_table "profiles", :force => true do |t|
    t.integer  "facebook_id",   :limit => 8, :default => 0
    t.string   "first_name"
    t.string   "last_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "votes",                      :default => 0
    t.integer  "votes_network",              :default => 0
    t.string   "full_name"
  end

  add_index "profiles", ["facebook_id"], :name => "idx_profiles_facebook_id", :unique => true

  create_table "results", :force => true do |t|
    t.integer  "facebook_id",  :limit => 8, :default => 0
    t.integer  "winner_id",    :limit => 8, :default => 0
    t.integer  "loser_id",     :limit => 8, :default => 0
    t.boolean  "left",                      :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "mode"
    t.integer  "winner_score"
    t.integer  "loser_score"
  end

  create_table "schools", :force => true do |t|
    t.integer  "facebook_id", :limit => 8, :default => 0
    t.integer  "school_id",   :limit => 8, :default => 0
    t.string   "school_name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "statistic_summary", :force => true do |t|
    t.string  "name",       :limit => 100
    t.string  "time_frame", :limit => 50
    t.integer "value"
  end

  create_table "temp_networks", :id => false, :force => true do |t|
    t.integer "id",                       :default => 0, :null => false
    t.integer "facebook_id", :limit => 8,                :null => false
    t.integer "friend_id",   :limit => 8,                :null => false
    t.integer "degree",                   :default => 0
  end

  add_index "temp_networks", ["facebook_id"], :name => "idx_facebook_id"
  add_index "temp_networks", ["friend_id"], :name => "idx_friend_id"

  create_table "temp_users", :primary_key => "facebook_id", :force => true do |t|
    t.integer  "id",                                   :default => 0,    :null => false
    t.string   "gender",                  :limit => 0
    t.integer  "score",                                :default => 1500
    t.integer  "wins",                                 :default => 0
    t.integer  "losses",                               :default => 0
    t.integer  "win_streak",                           :default => 0
    t.integer  "loss_streak",                          :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "wins_network",                         :default => 0
    t.integer  "losses_network",                       :default => 0
    t.integer  "win_streak_network",                   :default => 0
    t.integer  "loss_streak_network",                  :default => 0
    t.integer  "win_streak_max",                       :default => 0
    t.integer  "loss_streak_max",                      :default => 0
    t.integer  "win_streak_max_network",               :default => 0
    t.integer  "loss_streak_max_network",              :default => 0
  end

  add_index "temp_users", ["facebook_id"], :name => "facebook_id_UNIQUE", :unique => true
  add_index "temp_users", ["gender"], :name => "idx_gender"

  create_table "tokens", :force => true do |t|
    t.integer  "facebook_id",  :limit => 8, :default => 0
    t.string   "access_token"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "udid"
  end

  create_table "users", :force => true do |t|
    t.integer  "facebook_id",             :limit => 8, :default => 0
    t.string   "gender",                  :limit => 0
    t.integer  "score",                                :default => 1500
    t.integer  "wins",                                 :default => 0
    t.integer  "losses",                               :default => 0
    t.integer  "win_streak",                           :default => 0
    t.integer  "loss_streak",                          :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "wins_network",                         :default => 0
    t.integer  "losses_network",                       :default => 0
    t.integer  "win_streak_network",                   :default => 0
    t.integer  "loss_streak_network",                  :default => 0
    t.integer  "win_streak_max",                       :default => 0
    t.integer  "loss_streak_max",                      :default => 0
    t.integer  "win_streak_max_network",               :default => 0
    t.integer  "loss_streak_max_network",              :default => 0
    t.integer  "k_factor",                             :default => 32
    t.integer  "last_opponent_score",                  :default => 1500
    t.integer  "last_result_id",                       :default => 0
    t.integer  "judge_factor",                         :default => 1500
  end

  add_index "users", ["facebook_id"], :name => "idx_users_facebook_id", :unique => true
  add_index "users", ["gender"], :name => "index_users_on_gender"

end
