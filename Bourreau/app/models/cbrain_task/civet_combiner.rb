
#
# CBRAIN Project
#
# CbrainTask subclass for combining a set of partial
# CIVET results into a single larger CIVET result.
#
# Original author: Pierre Rioux
#
# $Id$
#

# A subclass of CbrainTask::ClusterTask to combine CIVET results.
class CbrainTask::CivetCombiner < CbrainTask::ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params       = self.params

    # List of collection IDs directly supplied
    civet_collection_ids = params[:civet_collection_ids] || ""
    civet_ids            = civet_collection_ids.split(/,/)

    # Fetch list of collection IDs indirectly through task list
    task_list_ids        = params[:civet_from_task_ids] || ""
    task_ids             = task_list_ids.split(/,/)
    task_ids.each do |tid|
      task    = CbrainTask.find(tid)
      tparams = task.params
      cid     = tparams[:output_civetcollection_id]
      cb_error "Could not found the output CIVET collection ID from task '#{task.bname_tid}'." if cid.blank?
      civet_ids << cid
    end

    # Save back full list of all collection IDs into params
    civet_ids.uniq!
    params[:civet_collection_ids] = civet_ids.join(",")

    # Get each source collection
    cols = []
    civet_ids.each do |id|
      col = Userfile.find(id.to_i)
      unless col && (col.is_a?(CivetCollection)) # || col.is_a?(CivetStudy))
        #self.addlog("Error: cannot find Civet Collection or Study with ID=#{id}")
        self.addlog("Error: cannot find CivetCollection with ID=#{id}")
        return false
      end
      cols << col
    end

    if cols.empty?
      self.addlog("Error: no valid collections supplied?")
      return false
    end

    # Synchronize them all
    self.addlog("Synchronizing collections to local cache")
    cols.each do |col|
      self.addlog("Synchronizing '#{col.name}'")
      self.save # so log messages appear as syncs happen
      col.sync_to_cache
    end
    self.addlog("Synchronization finished.")

    # Choose a DP id if none was supplied; we pick the first collections' DP.
    params[:data_provider_id] = cols[0].data_provider_id if params[:data_provider_id].blank?
    data_provider_id = params[:data_provider_id]

    # Check that all CIVET outputs have
    # 1) the same 'prefix'
    # 2) a distinct 'dsid'
    self.addlog("Checking collections: prefix and dsid...")
    seen_prefix = {}
    seen_dsid   = {}
    tcol_to_dsid = {}
    cols.each do |col|
      top = col.cache_full_path
      params_file  = top + "CBRAIN.params.yml"
      ymltext      = File.read(params_file) rescue ""
      if ymltext.blank?
        self.addlog("Could not find params file '#{params_file}' for CivetCollection '#{col.name}'.")
        return false
      end
      civet_params = YAML::load(ymltext)
      prefix = civet_params[:prefix] || civet_params['prefix']
      dsid   = civet_params[:dsid]   || civet_params['dsid']
      if prefix.blank?
        self.addlog("Could not find PREFIX for CivetCollection '#{col.name}'.")
        return false
      end
      if dsid.blank?
        self.addlog("Could not find DSID for CivetCollection '#{col.name}'.")
        return false
      end
      seen_prefix[prefix]   = true
      seen_dsid[dsid]     ||= 0
      seen_dsid[dsid]      += 1
      tcol_to_dsid["C#{col.id}"] = dsid
    end

    if seen_prefix.size != 1
      self.addlog("Error, found more than one PREFIX in the CIVET outputs: #{seen_prefix.keys.sort.join(', ')}")
      return false
    end

    prefix = seen_prefix.keys[0]

    if seen_dsid.values.select { |v| v > 1 }.size > 0
      reports = seen_dsid.map { |dsid,count| "'#{dsid}' x #{count}" }
      self.addlog("Error, found some DSIDs represented more than once: #{reports.sort.join(', ')}")
      return false
    end

    self.addlog("Combining results; PREFIX=#{prefix}, DSIDs=#{seen_dsid.keys.sort.join(', ')}")

    # Just record the PREFIX and the list of DSIDs in the task's params.
    params[:prefix] = prefix
    params[:dsids]  = tcol_to_dsid

  end

  def cluster_commands #:nodoc:
    params       = self.params
    user_id      = self.user_id

    nil   # Special case: no cluster job.
  end
  
  def save_results #:nodoc:
    params       = self.params
    user_id      = self.user_id
    user         = User.find(user_id)
    provid       = params[:data_provider_id]
    newname      = params[:civet_study_name]
    prefix       = params[:prefix] # set in setup() above
    tcol_to_dsid = params[:dsids]  # set in setup() above

    # Create new CivetStudy object to hold them all
    # and in the darkness bind them
    newstudy = safe_userfile_find_or_new(CivetStudy,
      :name             => newname,
      :user_id          => user_id,
      :data_provider_id => provid,
      :group_id         => user.own_group.id
    )

    # Save the new CivetStudy object
    unless newstudy.save
      cb_error "Cannot create a new CivetStudy named '#{newname}'."
    end

    # Now let's fill the new CivetStudy with everything in
    # the original collections; if anything fails, we need
    # to destroy the incomplete newstudy object.

    civet_collection_ids = params[:civet_collection_ids] || ""
    civet_ids = civet_collection_ids.split(/,/)
    cols = civet_ids.map { |id| Userfile.find(id) }

    self.addlog("Combining collections...")
    newstudy.addlog("Created by task #{self.bname_tid} with prefix '#{prefix}'")
    begin
      newstudy.cache_prepare
      coldir = newstudy.cache_full_path
      Dir.mkdir(coldir) unless File.directory?(coldir)
      errfile = self.stderr_cluster_filename

      # Issue rsync commands to combine the files
      cols.each do |col|
        col_id = col.id
        dsid   = tcol_to_dsid["C#{col_id}"]
        self.addlog("Adding #{col.class.to_s} '#{col.name}'")
        newstudy.addlog_context(self,"Adding #{col.class.to_s} '#{col.name}'")
        colpath = col.cache_full_path
        dsid_dir = coldir + dsid
        Dir.mkdir(dsid_dir.to_s) unless File.directory?(dsid_dir.to_s)
        rsyncout = IO.popen("rsync -a -l '#{colpath.to_s}/' #{dsid_dir} 2>&1 | tee -a #{errfile}","r") do |fh|
          fh.read
        end
        unless rsyncout.blank?
          cb_error "Error running rsync; rsync returned '#{rsyncout}'"
        end
      end
      newstudy.sync_to_provider
      newstudy.set_size
      newstudy.save
      params[:output_civetstudy_id] = newstudy.id

      # Option: destroy the original sources
      if params[:destroy_sources] && params[:destroy_sources].to_s == 'YeS'
        cols.each do |col|
          self.addlog("Destroying source #{col.class.to_s} '#{col.name}'")
          col.destroy rescue true
        end
      end

    rescue => itswrong
      newstudy.destroy
      raise itswrong
    end

    true
  end

end

