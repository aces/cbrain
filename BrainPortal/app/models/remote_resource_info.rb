
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

# This model encapsulates a record with a precise list
# of attributes. This is not an ActiveRecord, it's a
# subclass of Hash. See RestrictedHash for more info.
# Note that the attributes are used for an ActiveResource
# request, and therefore must be filled with strings.
#
# The attributes in this particular model are used to
# report on the state of a RemoteResource, when queried
# by another RemoteResource. This is performed by
# using the Controls controller and the Control
# ActiveResource, which are part of both CBRAIN
# Rails applications (BrainPortal and Bourreau).
class RemoteResourceInfo < RestrictedHash

   Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

   # List of allowed keys in the hash
   self.allowed_keys=[

     # General fields about a Remote Resource
     :id, :name,            # Rails app RemoteResource info
     :uptime,               # Rails app uptime in seconds

     # Host info
     :host_name,            # Value returned by Socket.gethostname
     :host_uname,           # Output of 'uname -a' command
     :host_ip,              # IP address as "1.2.3.4"
     :host_uptime,          # Output of 'uptime' command
     :rails_time_zone,      # Time zone name as configured in config/environment.rb

     # Svn info (Rails app)
     :revision,             # Latest GIT tag           on disk AT QUERYTIME, e.g. "3.1.13-121"
     :lc_author,            # Latest GIT commit author on disk AT QUERYTIME
     :lc_rev,               # Latest GIT commit ID     on disk AT QUERYTIME
     :lc_date,              # Latest GIT commit date   on disk AT QUERYTIME
     :starttime_revision,   # GIT tag AT STARTTIME, e.g. "3.1.13-121"

     # Statistics
     :num_cbrain_userfiles,       # Total number of userfiles in system; only filled when querying a BrainPortal
     :num_sync_cbrain_userfiles,  # Number of userfiles synced locally
     :size_sync_cbrain_userfiles, # Total size for the synced userfiles
     :num_cbrain_tasks,           # Number of CBRAIN tasks; grand total if querying a BrainPortal, or subset when querying a Bourreau
     :num_active_cbrain_tasks,    # Subset of num_cbrain_trasks that are ACTIVE_STATUS (see cbrain_tasks.rb)

     # Bourreau-specific fields
     :bourreau_cms, :bourreau_cms_rev,
     :tasks_max,    :tasks_tot,  # jobs on compute clusters

     # Bourreau Worker Svn info
     :worker_pids,
     :worker_lc_author,
     :worker_lc_rev,
     :worker_lc_date

   ]

   # Returns a dummy record filled with
   # mostly '???' for each field.
   def self.dummy_record
     mock_record("???")
   end

   def self.mock_record(field_value) #:nodoc:
     mock = self.new()

     mock = self.new()
     self.allowed_keys.each do |field|
       mock[field] = field_value
     end

     mock.id               = 0
     mock.bourreau_cms_rev = Object.revision_info.to_s # means 'unknown'

     mock
   end

   # Returns a default value of '???' for any attributes
   # not set.
   def [](key)
     super || "???"
   end

end

