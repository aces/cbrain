

class ModelsReport
  
  
  # Gather statistics about the userfile subclasses (types)
  # of files registered in the system.
  # The +options+ arguments can restrict the domain of the statistics
  # gathered:
  #
  #   * :users            => [ user, user...]
  #   * :providers        => [ dp, dp...]
  def self.gather_filetype_statistics(options)
    users            = options[:users]
    providers        = options[:providers]

    # Which users to gather stats for
    userlist = if users
                 users.is_a?(Array) ? users : [ users ]
               else
                 User.all
               end
    u_ids      = userlist.collect &:id
    user_by_id = userlist.index_by &:id
               
    # Which data providers to gather stats for
    dplist   = if providers
                 providers.is_a?(Array) ? providers : [ providers ]
               else
                 DataProvider.all
               end

    dp_ids = dplist.map &:id

    # Gather statistics
    user_fileclass_count = {}
    fileclasses_totcount = {}
    user_totcount        = {}
    all_totcount         = 0

    userfile_type_stats = Userfile.where( :data_provider_id => dp_ids, :user_id => u_ids ).group(:user_id, :type).count(:type)
    userfile_type_stats.each do |uid_type,type_count|
      user       = user_by_id[uid_type[0]]
      klass      =            uid_type[1]
      user_fileclass_count[user]               ||= {}
      user_fileclass_count[user][klass]        ||= 0
      user_fileclass_count[user][klass]         += type_count
      fileclasses_totcount[klass]              ||= 0
      fileclasses_totcount[klass]               += type_count
      user_totcount[user]                      ||= 0
      user_totcount[user]                       += type_count
      all_totcount                              += type_count
    end

    stats = {
              :user_fileclass_count => user_fileclass_count,
              :fileclasses_totcount => fileclasses_totcount,
              :user_totcount        => user_totcount,
              :all_totcount         => all_totcount
            }
    stats
  end
  
  
  
  # Gather statistics about the status and the type task
  # The +options+ arguments can restrict the domain of the statistics
  # gathered:
  #
  #   * :users            => [ user, user...]
  #   * :bourreau         => [ bourreau, bourreau...]
  def self.gather_task_statistics(options)
    users            = options[:users]
    bourreaux        = options[:bourreaux]
 
    # Which users to gather stats for
    userlist = if users
                 users.is_a?(Array) ? users : [ users ]
               else
                 User.all
               end
    u_ids      = userlist.map &:id
    user_by_id = userlist.index_by &:id
                
    # Which data providers to gather stats for
    blist   = if bourreaux
                 bourreaux.is_a?(Array) ? bourreaux : [ bourreaux ]
               else
                 Bourreau.all
               end
  
    b_ids = blist.map &:id
  
    statuses = { 'TOTAL' => 0 }
    user_tasks_info = {}
    types    = { 'TOTAL' => 0 }
    user_types_info = {}
     
    userlist.each do |user|
      user_tasks_info[user] ||= {}
      user_tasks_info[user]['TOTAL'] = 0
      user_types_info[user] ||= {}
      user_types_info[user]['TOTAL'] = 0
    end
    
    tasks_stats = CbrainTask.where( :bourreau_id => b_ids, :user_id => u_ids ).group(:user_id, :status).count(:status)
      
    tasks_stats.each do |uid_stat,stat_count|
      user       = user_by_id[uid_stat[0]]
      status     =            uid_stat[1]
      statuses[status]               ||= 0
      statuses[status]                += stat_count
      statuses['TOTAL']               += stat_count
      user_tasks_info[user]          ||= {}
      user_tasks_info[user][status]    = stat_count
      user_tasks_info[user]['TOTAL'] ||= 0
      user_tasks_info[user]['TOTAL']  += stat_count
    end

    types_stats = CbrainTask.where( :bourreau_id => b_ids, :user_id => u_ids ).group(:user_id, :type).count(:type)
      
    types_stats.each do |uid_type,type_count|
      user       = user_by_id[uid_type[0]]
      type       =            uid_type[1]
      types[type]                    ||= 0
      types[type]                     += type_count
      types['TOTAL']                  += type_count
      user_types_info[user]          ||= {}
      user_types_info[user][type]      = type_count
      user_types_info[user]['TOTAL'] ||= 0
      user_types_info[user]['TOTAL']  += type_count
    end

    statuses_list = statuses.keys.sort.reject { |s| s == 'TOTAL' }
    statuses_list << 'TOTAL'
    types_list    = types.keys.sort.reject    { |s| s == 'TOTAL' }
    types_list    << 'TOTAL'

    
    status_stats = { :statuses       => statuses,
                     :statuses_list  => statuses_list,
                     :user_task_info => user_tasks_info,
                   }

    type_stats   = { :types           => types,
                     :types_list      => types_list,
                     :user_types_info => user_types_info,
                   }

    [status_stats,type_stats]
  end


  
  # Creates and returns a table with statistics for disk usage on a
  # set of Data Providers.
  #
  # The +options+ arguments can restrict the domain of the statistics
  # gathered:
  #
  #   * :users            => [ user, user...]
  #   * :providers        => [ dp, dp...]
  def self.dp_usage_statistics(options)

    users            = options[:users]
    providers        = options[:providers]

    # Internal constants
    all_users_label  = all_dps_label = 'TOTAL'    

    # Which users to gather stats for
    userlist = if users
                 users.is_a?(Array) ? users : [ users ]
               else
                 User.all
               end

    # Which data providers to gather stats for
    dplist   = if providers
                 providers.is_a?(Array) ? providers : [ providers ]
               else
                 DataProvider.all
               end

    # All files that belong to these users on these data providers
    filelist = Userfile.where( {} )
    filelist = filelist.where( :user_id          => userlist.map(&:id) ) if ! users.nil?
    filelist = filelist.where( :data_provider_id => dplist.map(&:id)   ) if ! providers.nil?
    filelist = filelist.all

    # Arrays and hashes used to record the names of the
    # rows and columns of the report
    users_index = userlist.index_by &:id
    dp_index    = dplist.index_by   &:id

    # Stats structure. It represents a two-dimensional table
    # where rows are users and columns are data providers.
    # And extra row called 'All Users' sums up the stats for all users
    # on a data provider, and an extra row called 'All Providers' sums up
    # the stats for one users on all data providers.
    stats = { all_users_label => {} }

    tt_cell = stats[all_users_label][all_dps_label] = { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }

    filelist.each do |userfile|
      filetype          = userfile.class.to_s
      size              = userfile.size
      num_files         = userfile.num_files || 1

      user_id           = userfile.user_id
      user              = users_index[user_id]

      data_provider_id  = userfile.data_provider_id
      dp                = dp_index[data_provider_id]

      # up_cell is normal cell for one user on one dp
      # tp_cell is total cell for all users on one dp
      # ut_cell is total cell for on user on all dps
                stats[user]                ||= {} # row init
      up_cell = stats[user][dp]            ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
      tp_cell = stats[all_users_label][dp] ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
      ut_cell = stats[user][all_dps_label] ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }

      cells = [ up_cell, tp_cell, ut_cell, tt_cell ]

      # Update counts for all cells
      cells.each do |cell|
        if size
          cell[:size]        += size
          cell[:num_entries] += 1
          cell[:num_files]   += num_files
        else
          cell[:unknowns] += 1
        end
      end
    end

    users_final = users_index.values.sort { |a,b| a.login <=> b.login }
    dps_final   =    dp_index.values.sort { |a,b| a.name  <=> b.name  }

    stats['!users+all?!']  = users_final
    stats['!users+all?!'] += [ all_users_label ] if users_final.size > 1

    stats['!dps+all?!']     = dps_final
    stats['!dps+all?!']    += [ all_dps_label ] if dps_final.size > 1

    stats
end

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
    all_users_label  = all_dps_label = "TOTAL" # used as a key in the table's hash

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
    singles_hash     = base_rel.where([ "userfiles.type in (?)", SingleFile.descendants.map(&:name) + [ 'SingleFile' ]]).where("num_files is null").count

    # Arrays and hashes used to record the names of the
    # rows and columns of the report
    users_index = userlist.index_by &:id
    rr_index    = rrlist.index_by   &:id

    # Stats structure. It represents a two-dimensional table
    # where rows are users and columns are data providers.
    # And extra row called 'All Users' sums up the stats for all users
    # on a data provider, and an extra row called 'All Providers' sums up
    # the stats for one users on all data providers.
    stats = { all_users_label => {} }

    all_uid_rrid_pairs = num_entries_hash.keys | size_tot_hash.keys | num_files_hash.keys | num_unk_hash.keys | singles_hash.keys
    all_uid_rrid_pairs.each do |uid_rrid|
      num_entries = num_entries_hash[uid_rrid] || 0
      size_tot    = size_tot_hash[uid_rrid]    || 0
      num_files   = num_files_hash[uid_rrid]   || 0
      num_unk     = num_unk_hash[uid_rrid]     || 0
      num_singles = singles_hash[uid_rrid]     || 0

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
        cell[:num_files]   += num_files.to_i + num_singles.to_i
        cell[:unknowns]    += num_unk.to_i
      end
    end

    users_final = users_index.values.sort { |a,b| a.login <=> b.login }
    rrs_final   =    rr_index.values.sort { |a,b| a.name  <=> b.name  }

    stats['!users!']       = users_final
    stats['!users+all?!']  = users_final 
    stats['!users+all?!'] += [ all_users_label ] if users_final.size > 1

    stats['!rrs!']         = rrs_final

    stats
  end

end
