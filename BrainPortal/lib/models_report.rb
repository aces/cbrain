

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
  

end
