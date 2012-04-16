
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

#This model represents an group created for the purpose of assigning collective permission
#to resources (as opposed to SystemGroup). 
class WorkGroup < Group

  Revision_info=CbrainFileRevision[__FILE__]
    
  validates_uniqueness_of :name, :scope => :creator_id

  # This method optimizes the DB lookups necessary to 
  # create the pretty_category_name of a set of WorkGroups
  def self.prepare_pretty_category_names(groups = [], as_user = nil)
    wgs     = Array(groups).select { |g| g.is_a?(WorkGroup) }
    wg_ids  = wgs.map &:id

    wg_ucnt = WorkGroup.joins(:users).where('groups.id' => wg_ids).group('groups.id').count('users.login') # how many users per workgroup
    by_one_or_many = wgs.hashed_partition { |wg| wg_ucnt[wg.id] == 1 ? :one : :many }

    # Process workgroups with more than 1 user
    by_one_or_many[:many].each do |wg|
      wg.instance_eval { @_pretty_category_name = 'Shared Work Project' }
    end

    # A list of the first username of the workgroups with a single user
    wg_names_cache = Proc.new { 
      @_wg_names ||= WorkGroup.joins(:users).where(
                     'groups.id' => by_one_or_many[:one].map(&:id)).select(
                     [ 'groups.id', 'users.full_name', 'users.login' ]).all.index_by &:id # first user of each group
    }

    # Process workgroups with a single user
    wgs.select { |wg| wg_ucnt[wg.id] == 1 }.each do |wg|
      if as_user.present? && (wg.creator_id == as_user.id || wg_names_cache.call[wg.id].login == as_user.login)
        wg.instance_eval { @_pretty_category_name = "My Work Project" }
      else
        wg.instance_eval { @_pretty_category_name = "Personal Work Project of #{wg_names_cache.call[wg.id].full_name}" }
      end
    end

    wgs
  end
    
  def pretty_category_name(as_user)
    return @_pretty_category_name if @_pretty_category_name
    if self.users.count != 1
      @_pretty_category_name = 'Shared Work Project'
    elsif as_user.present? && (self.creator_id == as_user.id || self.users.first.id == as_user.id)
      @_pretty_category_name = 'My Work Project'
    else
      @_pretty_category_name = "Personal Work Project of #{self.users.first.login}"
    end
    @_pretty_category_name
  end
    
  def short_pretty_type
    if self.users.count > 1
      return "Shared"
    else
      return ""
    end
  end
  
  def can_be_edited_by?(user)
    if user.has_role? :admin_user
      return true
    elsif user.has_role? :site_manager
      if self.site_id == user.site.id
        return true
      end
    end
    return self.users.count == 1 && self.users.first == user
  end

end

