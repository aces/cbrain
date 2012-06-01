
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

class Invitation < Message

  Revision_info=CbrainFileRevision[__FILE__]
  
  belongs_to    :group
  
  before_create :make_active
  
  after_create  :add_description  #Need to put the id in there.
  
  
  def self.send_out(sender, group, users)
    self.send_message(users,
      message_type: "notice",
      header:       "You've been invited to join project #{group.name}",
      group_id:     group.id,
      send_email:   true,
      sender_id:    sender.id
    )
  end
  
  private
  
  def make_active
    self.active = true
  end
  
  def add_description
    self.description = "You've been invited to join project #{group.name}.\n\n"+
                       "[[Accept][/invitations/#{self.id}}][put]]"
    self.save!
  end
  
end
