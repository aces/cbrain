
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

# We are no longer supporing historical ways of encoding the
# password in the DB, so we transform all our special entries
# that were in the form "pbkdf2_sha1:ab0123..." to the plain
# simple hash "ab0123...".
class StandardizeToPbkdf2 < ActiveRecord::Migration

  def up
    User.all.each do |user|
      pwd = user.crypted_password
      next unless pwd =~ /^pbkdf2_sha1:[0-9a-f]{64}$/i
      pwd.sub!(/^pbkdf2_sha1:/i, "")
      user.update_column(:crypted_password, pwd)
    end
    true
  end

  def down
    User.all.each do |user|
      pwd = user.crypted_password
      next unless pwd =~ /^[0-9a-f]{64}$/
      user.update_column(:crypted_password, "pbkdf2_sha1:#{pwd}")
    end
    true
  end

end

