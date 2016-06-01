
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

# Model representing access profiles, a sort of
# record where pre-defined profiles for users are created
# by the admin. Later on, access restrictions will be
# recorded here too.
class AccessProfile < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of   :name
  validates_uniqueness_of :name

  has_and_belongs_to_many :groups
  has_and_belongs_to_many :users

  attr_accessible         :name, :color, :description, :group_ids, :user_ids

end

