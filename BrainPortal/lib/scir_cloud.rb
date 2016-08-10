
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

# This is a replacement for the drmaa.rb library; this particular subclass
# of class Scir implements a dummy cluster interface that still runs
# jobs locally as standard unix subprocesses.


# An abstract Scir class to access clouds.
class ScirCloud < Scir
  
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # An abstract method that returns an array containing instance types
  # available on this cloud, for instance:
  #     ["m1.small", "m2.large"]  
  def self.get_available_instance_types(bourreau)
    raise "Not implemented"
  end

  # An abstract method that returns an array containing arrays of size
  # 2 with the ids and names of disk images available to the bourreau,
  # for instance:
  #     [ ["CentOS7","ami-12345"], ["CentOS6","ami-6789"] ]
  # This (weird) data structure is used to pass the result of this method in a Rails select tag.
  def self.get_available_disk_images(bourreau)
    raise "Not implemented"
  end
  
  # An abstract method that returns an array containing arrays of size
  # 1 with the ids the key pairs available to the bourreau,
  # for instance:
  #     [ ["id_rsa_cbrain_portal"], ["personal_key"] ]
  # This (weird) data structure is used to pass the result of this method in a Rails select tag.
  def self.get_available_key_pairs(bourreau)
    raise "Not implemented"
  end

end

