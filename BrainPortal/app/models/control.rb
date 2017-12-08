
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

# The Control class implements a communication channel
# between two Rails applications. The precise list of
# attributes that are set inside the object varies depending
# on the request that is being made; right now when
# the Controls controller replies to a 'show' action,
# it fills a Control object with a populated RemoteResourceInfo
# object:
#
#     myinfo = RemoteResourceInfo.new() # acts like a Hash
#     tosend = Control.new(myinfo)
#
# When a command is sent from one RemoteResource to another,
# the Control object is filled with a RemoteCommand object:
#
#     mycom  = RemoteCommand.new(blah blah) # acts like a Hash
#     tosend = Control.new(mycom)
#
# The ActiveResource layer doesn't care that the data being
# shuffled back and forth is so polymorphic.
class Control < ActiveResource::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  self.format = :xml

end

