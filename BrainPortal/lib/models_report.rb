
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

# This class contains utility methods for generating some
# reports; it is slowly being phased out.
class ModelsReport

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Creates and returns a table with statistics for Remote Resource caches.
  #
  # The +options+ arguments can restrict the domain of the statistics
  # gathered:
  #
  #   * :users            => [ user, user...]
  #   * :remote_resources => [ rr, rr...]
  #   * :accessed_before  => Time
  #   * :accessed_after   => Time
  #
  # The accessed_* options apply to the cached userfiles
  # on the remote_resources, and are compared to the
  # :accessed_at attribute of the SyncStatus structure.
  def self.rr_usage_statistics(options)
    users            = options[:users]
    remote_resources = options[:remote_resources]
    accessed_before  = options[:accessed_before]
    accessed_after   = options[:accessed_after]

    # Internal constants
    all_users_label = "TOTAL" # used as a key in the table's hash

    # Which users to gather stats for
    userlist = if users
                 users.is_a?(Array) ? users : [ users ]
               else
                 User.all
               end

    # Which remote resource to gather stats for
    rrlist   = if remote_resources
                 remote_resources.is_a?(Array) ? remote_resources : [ remote_resources ]
               else
                 RemoteResource.all
               end

    # Base relation for file status
    base_rel = SyncStatus.joins(:userfile).group([ 'userfiles.user_id', 'sync_status.remote_resource_id'])
#    base_rel = base_rel.where(:status => [ 'InSync', 'Corrupted', 'CacheNewer', 'ToCache', 'ToProvider' ])
    base_rel = base_rel.where("userfiles.user_id" => userlist.map(&:id)) if users.present?
    base_rel = base_rel.where(:remote_resource_id => rrlist.map(&:id))   if remote_resources.present?
    base_rel = base_rel.where([ "accessed_at < ?", accessed_before])     if accessed_before.present?
    base_rel = base_rel.where([ "accessed_at > ?", accessed_after])      if accessed_after.present?

    # The four queries with the stats
    num_entries_hash = base_rel.count
    size_tot_hash    = base_rel.sum(:size)
    num_files_hash   = base_rel.sum(:num_files)
    num_unk_hash     = base_rel.where("size is null").count

    # Arrays and hashes used to record the names of the
    # rows and columns of the report
    users_index = userlist.index_by(&:id)
    rr_index    = rrlist.index_by(&:id)

    # Stats structure. It represents a two-dimensional table
    # where rows are users and columns are data providers.
    # And extra row called 'All Users' sums up the stats for all users
    # on a data provider, and an extra row called 'All Providers' sums up
    # the stats for one users on all data providers.
    stats = { all_users_label => {} }

    all_uid_rrid_pairs = num_entries_hash.keys | size_tot_hash.keys | num_files_hash.keys | num_unk_hash.keys
    all_uid_rrid_pairs.each do |uid_rrid|
      num_entries = num_entries_hash[uid_rrid] || 0
      size_tot    = size_tot_hash[uid_rrid]    || 0
      num_files   = num_files_hash[uid_rrid]   || 0
      num_unk     = num_unk_hash[uid_rrid]     || 0

      user_id = uid_rrid[0].to_i  # might be a string as a consequence of join
      user    = users_index[user_id]
      next unless user # just to be safe, should never happen

      rr_id   = uid_rrid[1].to_i  # might be a string as a consequence of join
      rr      = rr_index[rr_id]
      next unless rr # just to be safe, should never happen

      stats[user]                ||= {} # row init
      cells = []

      # rr_cell is normal cell for one user on one remote resource
      # tr_cell is total cell for all users on one remote resource
      rr_cell = stats[user][rr]            ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
      tr_cell = stats[all_users_label][rr] ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
      cells << rr_cell
      cells << tr_cell

      # Update counts for all cells
      cells.each do |cell|
        cell[:size]        += size_tot.to_i
        cell[:num_entries] += num_entries.to_i
        cell[:num_files]   += num_files.to_i
        cell[:unknowns]    += num_unk.to_i
      end
    end

    users_final = users_index.values.sort { |a,b| a.login <=> b.login }
    rrs_final   =    rr_index.values.sort { |a,b| a.name  <=> b.name  }

    stats['!users!']       = users_final
    stats['!rrs!']         = rrs_final

    stats
  end

end

