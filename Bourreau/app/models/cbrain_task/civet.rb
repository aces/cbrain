
#
# CBRAIN Project
#
# This class runs the CIVET pipeline on
# one t1 MINC file, producing one CivetCollection result (one
# subject only).
#
# Original author: Pierre Rioux
#
# $Id$
#

# A subclass of ClusterTask to run CIVET.
class CbrainTask::Civet < ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params       = self.params
    file0        = params[:file_args]["0"] # we require this single entry for info on the data files

    prefix       = file0[:prefix] || "unkpref1"
    dsid         = file0[:dsid]   || "unkdsid1"

    # Main location of symlinks for all input files
    safe_mkdir("mincfiles",0700)

    # Main location for output files
    safe_mkdir("civet_out",0700)

    # We have two modes:
    # (A) We process a T1 (and T2?, PD?, and MK?) file(s) stored inside a FileCollection
    # (B) We process a T1 (and T2?, PD?, and MK?) stored as individual SingleFiles.
    # - We detect (A) when we have a collection_id, and then the
    #   files are specified with :t1_name, :t2_name, etc.
    # - We detect (B) when we have do NOT have a collection ID, and then the
    #   files are specified with :t1_id, :t2_id, etc.

    collection_id = params[:collection_id]
    collection_id = nil if collection_id.blank?
    collection    = nil # the variable we use to detect modes
    if collection_id # MODE A: collection
      collection = Userfile.find(collection_id)
      unless collection
        self.addlog("Could not find active record entry for FileCollection '#{collection_id}'.")
        return false
      end
      collection.sync_to_cache
      t1_name = file0[:t1_name]  # cannot be nil
      t2_name = file0[:t2_name]  # can be nil
      pd_name = file0[:pd_name]  # can be nil
      mk_name = file0[:mk_name]  # can be nil
    else # MODE B: singlefiles
      t1_id  = file0[:t1_id]  # cannot be nil
      t1 = Userfile.find(t1_id)
      unless t1
        self.addlog("Could not find active record entry for singlefile '#{t1_id}'.")
        return false
      end
      t1.sync_to_cache
      t2_id  = file0[:t2_id]  # can be nil
      pd_id  = file0[:pd_id]  # can be nil
      mk_id  = file0[:mk_id]  # can be nil
    end

    # Setting the data_provider_id here means it persists
    # in the ActiveRecord params structure for later use.
    if params[:data_provider_id].blank?
       params[:data_provider_id] = collection.data_provider.id if collection
       params[:data_provider_id] = t1.data_provider.id if ! collection
    end

    # MODE A (collection) symlinks
    if collection
      colpath = collection.cache_full_path.to_s

      t1ext   = t1_name.match(/.gz$/i) ? ".gz" : ""
      safe_symlink("#{colpath}/#{t1_name}","mincfiles/#{prefix}_#{dsid}_t1.mnc#{t1ext}")

      if file0[:multispectral] || file0[:spectral_mask]
        if t2_name
          t2ext = t2_name.match(/.gz$/i) ? ".gz" : ""
          safe_symlink("#{colpath}/#{t2_name}","mincfiles/#{prefix}_#{dsid}_t2.mnc#{t2ext}")
        end
        if pd_name
          pdext = pd_name.match(/.gz$/i) ? ".gz" : ""
          safe_symlink("#{colpath}/#{pd_name}","mincfiles/#{prefix}_#{dsid}_pd.mnc#{pdext}")
        end
        if mk_name
          mkext = mk_name.match(/.gz$/i) ? ".gz" : ""
          safe_symlink("#{colpath}/#{mk_name}","mincfiles/#{prefix}_#{dsid}_mask.mnc#{mkext}")
        end
      end

    else   # MODE B (singlefiles) symlinks

      t1_name     = t1.name
      t1cachename = t1.cache_full_path.to_s
      t1ext       = t1_name.match(/.gz$/i) ? ".gz" : ""
      safe_symlink(t1cachename,"mincfiles/#{prefix}_#{dsid}_t1.mnc#{t1ext}")

      if file0[:multispectral] || file0[:spectral_mask]
        if t2_id
          t2cachefile = Userfile.find(t2_id)
          t2cachefile.sync_to_cache
          t2cachename = t2cachefile.cache_full_path.to_s
          t2ext = t2cachename.match(/.gz$/i) ? ".gz" : ""
          safe_symlink(t2cachename,"mincfiles/#{prefix}_#{dsid}_t2.mnc#{t2ext}")
        end

        if pd_id
          pdcachefile = Userfile.find(pd_id)
          pdcachefile.sync_to_cache
          pdcachename = pdcachefile.cache_full_path.to_s
          pdext = pdcachename.match(/.gz$/i) ? ".gz" : ""
          safe_symlink(pdcachename,"mincfiles/#{prefix}_#{dsid}_pd.mnc#{pdext}")
        end

        if mk_id
          mkcachefile = Userfile.find(mk_id)
          mkcachefile.sync_to_cache
          mkcachename = mkcachefile.cache_full_path.to_s
          mkext = mkcachename.match(/.gz$/i) ? ".gz" : ""
          safe_symlink(mkcachename,"mincfiles/#{prefix}_#{dsid}_mask.mnc#{mkext}")
        end
      end # if multispectral or spectral_mask
    end # MODE B

    true
  end

  def cluster_commands #:nodoc:
    params = self.params
    file0  = params[:file_args]["0"] # we require this single entry for info on the data files

    prefix = file0[:prefix] || "unkpref2"
    dsid   = file0[:dsid]   || "unkdsid2"

    # Cheating mode (for debugging/development)
    fake_id = params[:fake_run_civetcollection_id]
    unless fake_id.blank?
      self.addlog("Triggering fake run with pre-saved collection ID '#{fake_id}'.")
      ccol = CivetCollection.find(fake_id)
      ccol.sync_to_cache
      ccol_path = ccol.cache_full_path
      FileUtils.remove_entry("civet_out/#{dsid}",true)
      FileUtils.cp_r(ccol_path,"civet_out/#{dsid}")
      return nil # no shell commands run.
    end

    args = ""

    args += "-make-graph "                          if mybool(params[:make_graph])
    args += "-make-filename-graph "                 if mybool(params[:make_filename_graph])
    args += "-print-status-report "                 if mybool(params[:print_status_report])
    args += "-template #{params[:template]} "       if ! params[:template].blank?
    args += "-model #{params[:model]} "             if ! params[:model].blank?
    args += "-interp #{params[:interp]} "           if ! params[:interp].blank?
    args += "-N3-distance #{params[:N3_distance]} " if ! params[:N3_distance].blank?
    args += "-lsq#{params[:lsq]} "                  if params[:lsq] && params[:lsq].to_i != 9 # there is NO -lsq9 option!
    args += "-no-surfaces "                         if mybool(params[:no_surfaces])
    args += "-correct-pve "                         if mybool(params[:correct_pve])
    args += "-resample-surfaces "                   if mybool(params[:resample_surfaces])
    args += "-combine-surfaces "                    if mybool(params[:combine_surfaces])

    args += "-multispectral "                       if mybool(file0[:multispectral])
    args += "-spectral_mask "                       if mybool(file0[:spectral_mask])

    if ! params[:thickness_method].blank? && ! params[:thickness_kernel].blank?
        args += "-thickness #{params[:thickness_method]} #{params[:thickness_kernel]} "
    end

    if mybool(params[:VBM])
        args += "-VBM "
        args += "-VBM-symmetry "                    if mybool(params[:VBM_symmetry])
        args += "-VBM-cerebellum "                  if mybool(params[:VBM_cerebellum])
        args += "-VBM-fwhm #{params[:VBM_fwhm]} "   if ! params[:VBM_fwhm].blank?
    end

    civet_command = "CIVET_Processing_Pipeline -prefix #{prefix} -source mincfiles -target civet_out -spawn #{args} -run #{dsid}"

    self.addlog("Full CIVET command:\n  #{civet_command.gsub(/ -/, "\n  -")}")

    return [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "export PATH=\"#{CBRAIN::CIVET_dir}:$PATH\"",
      "echo \"\";echo Showing ENVIRONMENT",
      "env | sort",
      "echo \"\";echo Starting CIVET",
      "echo Command: #{civet_command}",
      "#{civet_command}"
    ]

  end

  def save_results #:nodoc:
    params       = self.params
    file0        = params[:file_args]["0"] # we require this single entry for info on the data files

    user_id      = self.user_id

    prefix           = file0[:prefix] || "unkpref2"
    dsid             = file0[:dsid]   || "unkdsid2"
    data_provider_id = params[:data_provider_id]

    # Unique identifier for this run
    uniq_run = self.bname_tid_dashed + "-" + self.run_number.to_s

    collection_id = params[:collection_id]
    collection_id = nil if collection_id.blank?

    source_userfile = nil # the variable we use to detect modes

    if collection_id  # MODE A FileCollection
      source_userfile = FileCollection.find(collection_id)
    else              # MODE B SingleFile
      t1_id           = file0[:t1_id]
      source_userfile = SingleFile.find(t1_id)
    end

    group_id = source_userfile.group_id 

    # Where we find this subject's results
    out_dsid = "civet_out/#{dsid}"

    # Let's make sure it ran OK, test #1
    unless File.directory?(out_dsid)
      self.addlog("Error: this CIVET run did not complete successfully.")
      self.addlog("We couldn't find the result subdirectory '#{out_dsid}' !")
      return false
    end

    # Next block commented-out until we find a better
    # criterion for detecting failed tasks.

    # Let's make sure it ran OK, test #2
    #logfiles = Dir.entries("#{out_dsid}/logs")
    #badnews  = logfiles.select { |lf| lf =~ /\.(fail(ed)?|running|lock)$/i }
    #unless badnews.empty?
    #  self.addlog("Error: this CIVET run did not complete successfully.")
    #  self.addlog("We found these files in 'logs' : #{badnews.sort.join(', ')}")
    #  return false
    #end

    # Create new CivetCollection
    civetresult = safe_userfile_find_or_new(CivetCollection,
      :name             => dsid + "-" + uniq_run,
      :user_id          => user_id,
      :group_id         => group_id,
      :data_provider_id => data_provider_id,
      :task             => "Civet"
    )
    unless civetresult.save
      params.delete(:output_civetcollection_id)
      cb_error "Could not save back result file '#{civetresult.name}'."
    end

    # Record collection's ID in task's params
    params[:output_civetcollection_id] = civetresult.id

    # Move or copy some useful files into the collection before creating it.
    File.rename("civet_out/References.txt", "#{out_dsid}/References.txt")                     rescue true
    FileUtils.cp(self.stdout_cluster_filename,  "#{out_dsid}/logs/CBRAIN_#{uniq_run}.stdout.txt") rescue true
    FileUtils.cp(self.stderr_cluster_filename,  "#{out_dsid}/logs/CBRAIN_#{uniq_run}.stderr.txt") rescue true

    # Transform symbolic links in 'native/' into real files.
    Dir.chdir("#{out_dsid}/native") do
      Dir.foreach(".") do |file|
        next unless File.symlink?(file)
        realsource = File.readlink(file)  # this might itself be a symlink, that's ok.
        File.rename(file,"#{file}.tmp")
        FileUtils.cp_r(realsource,file)
        File.unlink("#{file}.tmp")
      end
    end

    # Dump a serialized file with the contents of the params used to generate
    # this result set.
    run_params_file = "#{out_dsid}/CBRAIN_#{uniq_run}.params.yml"
    params_link     = "#{out_dsid}/CBRAIN.params.yml"
    File.open(run_params_file,"w") do |fh|
      fh.write(params.to_yaml)
    end
    File.unlink(params_link) rescue true
    File.symlink(run_params_file.sub(/.*\//,""),params_link) rescue true

    # Copy the CIVET result's content to the DataProvider's cache (and provider too)
    civetresult.cache_copy_from_local_file(out_dsid)

    # Log information
    self.addlog_to_userfiles_these_created_these([ source_userfile ],[ civetresult ])
    civetresult.move_to_child_of(source_userfile)
    self.addlog("Saved new CIVET result file #{civetresult.name}.")
    true

  end

  # My old convention was '1' for true, "" for false;
  # the new form helpers send '1' for true and '0' for false.
  private

  def mybool(value) #:nodoc:
    return false if value.blank?
    return false if value.is_a?(String)  and value == "0"
    return false if value.is_a?(Numeric) and value == 0
    return true
  end

end

