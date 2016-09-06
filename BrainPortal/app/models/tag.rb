
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

#Model representing user-defined tags.
#
#=Attributes:
#[*name*] A string representing the name of the tag.
#= Associations:
#*Belongs* *to*:
#* User
#*Has* *and* *belongs* *to* *many*:
#* Userfile
class Tag < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of   :name, :user_id, :group_id
  validates_uniqueness_of :name, :scope => :group_id
  validates_format_of     :name,  :with => /\A[\w\-\=\.\+\?\!\s]*\z/,
                                  :message  => 'only the following characters are valid: alphanumeric characters, spaces, _, -, =, +, ., ?, !'

  has_and_belongs_to_many :userfiles
  belongs_to              :user
  belongs_to              :group

  attr_accessible         :name, :user_id, :group_id

end

