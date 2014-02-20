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


# For Bourreaux with ScirOpenStack type of cluster.
# This class associates a Disk Image Bourreau to an OpenStack disk image id and flavor. 

class DiskImageConfig < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  belongs_to     :bourreau   
  belongs_to     :disk_image_bourreau 

  attr_accessible :bourreau_id, :disk_image_bourreau_id, :open_stack_disk_image_id, :open_stack_default_flavor

end
