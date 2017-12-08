
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

class CreateLargeSessionInfoTable < ActiveRecord::Migration[5.0]
  def change
    create_table "large_session_infos", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.string   "session_id",               null: false
      t.text     "data",       limit: 65535
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "user_id"
      t.boolean  "active",                   default: false
      t.index ["session_id"], name: "index_sessions_on_session_id", using: :btree
      t.index ["updated_at"], name: "index_sessions_on_updated_at", using: :btree
    end
  end
end

