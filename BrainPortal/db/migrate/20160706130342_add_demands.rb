class AddDemands < ActiveRecord::Migration
  def up
    create_table :demands do |t|
      t.string   "title"
      t.string   "first", null: false
      t.string   "middle"
      t.string   "last", null: false
      t.string   "institution", null: false
      t.string   "department"
      t.string   "position"
      t.string   "email", null: false
      t.string   "website"
      t.string   "street1"
      t.string   "street2"
      t.string   "city"
      t.string   "province"
      t.string   "country"
      t.string   "postal_code"
      t.string   "time_zone"
      t.string   "service"
      t.string   "login"
      t.string   "comment"

      t.string   "session_id"
      t.string   "confirm_token"
      t.boolean  "confirmed"

      t.string   "approved_by"
      t.datetime "approved_at"

      t.datetime "created_at"
      t.datetime "updated_at"

      t.timestamps
    end

  end

  def self.down
    drop_table :demands
  end
end
