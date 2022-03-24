
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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

# Model representing usage of files in select groups
class DataUsage < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :user_id
  validates_presence_of :group_id
  validates_presence_of :yearmonth

  belongs_to :user,  :optional => false
  belongs_to :group, :optional => false

  validates_uniqueness_of :user_id, :scope => [ :group_id, :yearmonth ]

  def self.increase_views(user, userfile)
    return nil unless userfile.group.track_usage?
    self.addcount(user.id, userfile.group.id, userfile.num_files, :views)
  end

  def self.increase_downloads(user, userfile)
    return nil unless userfile.group.track_usage?
    self.addcount(user.id, userfile.group.id, userfile.num_files, :downloads)
  end

  def self.increase_copies(user, userfile)
    return nil unless userfile.group.track_usage?
    self.addcount(user.id, userfile.group.id, userfile.num_files, :copies)
  end

  def self.increase_task_setups(user, userfile)
    return nil unless userfile.group.track_usage?
    self.addcount(user.id, userfile.group.id, userfile.num_files, :task_setups)
  end

  protected

  def self.addcount(user_id, group_id, num_files, attname)
    # Find or create the tracking record
    yearmonth = Time.now.utc.strftime("%Y-%m")
    track = DataUsage.find_or_create_by(
      :user_id   => user_id,
      :group_id  => group_id,
      :yearmonth => yearmonth,
    )
    # Update the two attributes (e.g. views_count and views_numfiles)
    attname_count    = "#{attname}_count".to_sym
    attname_numfiles = "#{attname}_numfiles".to_sym
    track[attname_count]    += 1
    track[attname_numfiles] += num_files || 1
    track.save
  rescue
    nil # probably a race condition, doesn't matter all that much
  end

end
