
module DataProvidersHelper

  Revision_info=CbrainFileRevision[__FILE__]
  
  def class_param_for_name(name, klass=Userfile) #:nodoc:
    matched_class = klass.descendants.unshift(klass).find{ |c| name =~ c.file_name_pattern }
    
    if matched_class
      "#{matched_class.name}-#{name}"
    else
      nil
    end
  end

  # Creates and returns a table with statistics for disk usage on a
  # set of Data Providers and Remote Resource caches.
  #
  # The +options+ arguments can restrict the domain of the statistics
  # gathered:
  #
  #   * :users            => [ user, user...]
  #   * :providers        => [ dp, dp...]
  #   * :remote_resources => [ rr, rr...]
  #   * :accessed_before  => Time
  #   * :accessed_after   => Time
  #
  # The accessed_* options apply to the cached userfiles
  # on the remote_resources, and are compared to the
  # :accessed_at attribute of the SyncStatus structure.
  def gather_dp_usage_statistics(options)

    users            = options[:users]
    providers        = options[:providers]
    remote_resources = options[:remote_resources]
    accessed_before  = options[:accessed_before]
    accessed_after   = options[:accessed_after]

    # Internal constants
    all_users_label  = 'All Users'     # used as a key in the table's hash
    all_dps_label    = 'All Providers' # used as a key in the table's hash

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

    # Which remote resource to gather stats for
    rrlist   = if remote_resources
                 remote_resources.is_a?(Array) ? remote_resources : [ remote_resources ]
               else
                 RemoteResource.all
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
    rr_index    = rrlist.index_by   &:id

    # Record which users and DP ids have at least some data
    user_ids_seen = {}
    dp_ids_seen   = {}
    rr_ids_seen   = {}

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

      user_ids_seen[user_id]        = true
      dp_ids_seen[data_provider_id] = true

      # up_cell is normal cell for one user on one dp
      # tp_cell is total cell for all users on one dp
      # ut_cell is total cell for on user on all dps
                stats[user]                ||= {} # row init
      up_cell = stats[user][dp]            ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
      tp_cell = stats[all_users_label][dp] ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
      ut_cell = stats[user][all_dps_label] ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }

      cells = [ up_cell, tp_cell, ut_cell, tt_cell ]

      # Gather information from caches on remote_resources
      synclist = userfile.sync_status
      synclist.each do |syncstat| # we assume ALL status keywords mean there is some content in the cache

        # Only syncstats on the remote_resources we want to look at
        rr_id   = syncstat.remote_resource_id
        rr      = rr_index[rr_id]
        next unless rr

        # Only syncstats with proper access time
        accessed_at = syncstat.accessed_at
        next if accessed_before && accessed_at > accessed_before
        next if accessed_after  && accessed_at < accessed_after

        rr_ids_seen[rr_id] = true

        # rr_cell is normal cell for one user on one remote resource
        # tr_cell is total cell for all users on one remote resource
        rr_cell = stats[user][rr]            ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
        tr_cell = stats[all_users_label][rr] ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
        cells << rr_cell
        cells << tr_cell
      end

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

    users_final = users_index.values.select { |x| user_ids_seen[x.id] }.sort { |a,b| a.login <=> b.login }
    dps_final   =    dp_index.values.select { |x|   dp_ids_seen[x.id] }.sort { |a,b| a.name  <=> b.name  }
    rrs_final   =    rr_index.values.select { |x|   rr_ids_seen[x.id] }.sort { |a,b| a.name  <=> b.name  }

    stats['!users!']       = users_final
    stats['!users+all?!']  = users_final
    stats['!users+all?!'] += [ all_users_label ] if users_final.size > 1

    stats['!dps!']          = dps_final
    stats['!dps+all?!']     = dps_final
    stats['!dps+all?!']    += [ all_dps_label ] if dps_final.size > 1

    stats['!rrs!']          = rrs_final

    # These two entries are provided so that
    # the presentation layer can tell which entries
    # are the special summation columns
    stats['!all_users_label!'] = all_users_label
    stats['!all_dps_label!']   = all_dps_label

    stats
  end

  # Returns a RGB color code '#000000' to '#ffffff'
  # for size; the values are all fully saturated
  # and move about the colorwheel from pure blue
  # to pure red along the edge of the wheel. This
  # means no white or black or greys is ever returned
  # by this method. Max indicate to which values
  # and above the pure 'red' results corresponds to.
  # Red axis   = angle   0 degrees
  # Green axis = angle 120 degrees
  # Blue axis  = angle 240 degrees
  # The values are spread from angle 240 down towards angle 0
  def size_to_color(size,max=500_000_000_000)
    size     = max if size > max
    percent  = Math.log(1+size.to_f)/Math.log(max.to_f)
    angle    = 240-240*percent # degrees

    r_adist = (angle -   0.0).abs ; r_adist = 360.0 - r_adist if r_adist > 180.0
    g_adist = (angle - 120.0).abs ; g_adist = 360.0 - g_adist if g_adist > 180.0
    b_adist = (angle - 240.0).abs ; b_adist = 360.0 - b_adist if b_adist > 180.0

    r_pdist = r_adist < 60.0 ? 1.0 : r_adist > 120.0 ? 0.0 : 1.0 - (r_adist - 60.0)/60.0
    g_pdist = g_adist < 60.0 ? 1.0 : g_adist > 120.0 ? 0.0 : 1.0 - (g_adist - 60.0)/60.0
    b_pdist = b_adist < 60.0 ? 1.0 : b_adist > 120.0 ? 0.0 : 1.0 - (b_adist - 60.0)/60.0

    red   = r_pdist * 255
    green = g_pdist * 255
    blue  = b_pdist * 255

    sprintf "#%2.2x%2.2x%2.2x",red,green,blue
  end

end

