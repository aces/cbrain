
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

  # This method implements the 'search for anything' for the controller portal action +search+
  # It's also used in the rails console's shortcuts.
  #
  # If +token+ looks like an ID, the models are searched by ID only.
  # Otherwise, models are searched by name, version_name, description, etc.
  #
  # It returns a hash table with these keys:
  #
  #   {
  #     :users  => [],  # array of User objects
  #     :tasks  => [],  # CbrainTask objects
  #     :groups => [],  # Group objects
  #     :files  => [],  # Userfile objects
  #     :rrs    => [],  # RemoteResource objects
  #     :dps    => [],  # DataProvider objects
  #     :sites  => [],  # Site objects
  #     :tools  => [],  # Tool objects
  #     :tcs    => [],  # ToolConfig objects
  #   }
  def self.search_for_token(token, user=current_user) #:nodoc:

    token       = token.to_s.presence || "-999"
    is_numeric  = token =~ /^\d+$/    || token == "-999"


    file_scope  = Userfile      .find_all_accessible_by_user(user) .order(:name)
    task_scope  = CbrainTask    .find_all_accessible_by_user(user) .order(:id)
    rr_scope    = RemoteResource.find_all_accessible_by_user(user) .order(:name)
    dp_scope    = DataProvider  .find_all_accessible_by_user(user) .order(:name)
    tool_scope  = Tool          .find_all_accessible_by_user(user) .order(:name)
    tc_scope    = ToolConfig    .find_all_accessible_by_user(user) .order(:tool_id)

    # For the next three, wow: 'available' and 'accessible' have reverse meaning!
    # 'available' means user can modify them, 'accessible' means they can only view.
    user_scope  = user.available_users  .order(:login)
    group_scope = user.available_groups .order(:name)
    site_scope  = user.accessible_sites .order(:name)

    results = if (is_numeric)
      {
        :users  => Array(user_scope  .find_by_id(token)) ,
        :tasks  => Array(task_scope  .find_by_id(token)) ,
        :groups => Array(group_scope .find_by_id(token)) ,
        :files  => Array(file_scope  .find_by_id(token)) ,
        :rrs    => Array(rr_scope    .find_by_id(token)) ,
        :dps    => Array(dp_scope    .find_by_id(token)) ,
        :sites  => Array(site_scope  .find_by_id(token)) ,
        :tools  => Array(tool_scope  .find_by_id(token)) ,
        :tcs    => Array(tc_scope    .find_by_id(token)) ,
      }
    else
      ptoken = "%#{token}%"
      {
        :users  => user_scope  .where( [ "login like ? OR full_name like ? OR email like ?", ptoken, ptoken, ptoken ] ).all ,
        :tasks  => task_scope  .where( [ "description like ?"                              , ptoken                 ] ).all ,
        :groups => group_scope .where( [ "name like ?"                                     , ptoken                 ] ).all ,
        :files  => file_scope  .where( [ "name like ? OR description like ?"               , ptoken, ptoken         ] ).all ,
        :rrs    => rr_scope    .where( [ "name like ? OR description like ?"               , ptoken, ptoken         ] ).all ,
        :dps    => dp_scope    .where( [ "name like ? OR description like ?"               , ptoken, ptoken         ] ).all ,
        :sites  => site_scope  .where( [ "name like ? OR description like ?"               , ptoken, ptoken         ] ).all ,
        :tools  => tool_scope  .where( [ "name like ? OR description like ?"               , ptoken, ptoken         ] ).all ,
        :tcs    => tc_scope    .where( [ "version_name like ? OR description like ?"       , ptoken, ptoken         ] ).all ,
      }
    end

    results
  end

end

