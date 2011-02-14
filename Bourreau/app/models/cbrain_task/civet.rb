
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
  include RecoverableTask # This task is naturally recoverable, almost! See recover_from_cluster_failure() below.

  def setup #:nodoc:
    params       = self.params        || {}
    file_args    = params[:file_args] || {}
    if file_args.size > 1
      self.addlog("Parallel CIVETs being setup (x #{file_args.size}).")
    end
    file_args.each_key.sort { |a,b| a.to_i <=> b.to_i }.each do |arg_idx|
      self.addlog("Setting up CIVET '##{arg_idx}' for subject '#{file_args[arg_idx][:dsid]}'") if file_args.size > 1
      return false unless setup_single(arg_idx)
    end
    true
  end

  def setup_single(arg_idx) #:nodoc:
    params       = self.params
    file0        = params[:file_args][arg_idx] # we require this single entry for info on the data files

    prefix       = file0[:prefix] || "unkpref1"
    dsid         = file0[:dsid]   || "unkdsid1"

    # Main location of symlinks for all input files
    mincfiles_dir = "mincfiles_#{arg_idx}"
    safe_mkdir(mincfiles_dir,0700) # may already exist

    # Main location for output files
    safe_mkdir("civet_out",0700) # may already exist

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
      t1sym   = "#{mincfiles_dir}/#{prefix}_#{dsid}_t1.mnc#{t1ext}"
      safe_symlink("#{colpath}/#{t1_name}",t1sym)
      return false unless validate_minc_file(t1sym)

      if file0[:multispectral] || file0[:spectral_mask]
        if t2_name
          t2ext = t2_name.match(/.gz$/i) ? ".gz" : ""
          t2sym = "#{mincfiles_dir}/#{prefix}_#{dsid}_t2.mnc#{t2ext}"
          safe_symlink("#{colpath}/#{t2_name}",t2sym)
          return false unless validate_minc_file(t2sym)
        end
        if pd_name
          pdext = pd_name.match(/.gz$/i) ? ".gz" : ""
          pdsym = "#{mincfiles_dir}/#{prefix}_#{dsid}_pd.mnc#{pdext}"
          safe_symlink("#{colpath}/#{pd_name}",pdsym)
          return false unless validate_minc_file(pdsym)
        end
        if mk_name
          mkext = mk_name.match(/.gz$/i) ? ".gz" : ""
          mksym = "#{mincfiles_dir}/#{prefix}_#{dsid}_mask.mnc#{mkext}"
          safe_symlink("#{colpath}/#{mk_name}",mksym)
          return false unless validate_minc_file(mksym)
        end
      end

    else   # MODE B (singlefiles) symlinks

      t1_name     = t1.name
      t1cachename = t1.cache_full_path.to_s
      t1ext       = t1_name.match(/.gz$/i) ? ".gz" : ""
      t1sym       = "#{mincfiles_dir}/#{prefix}_#{dsid}_t1.mnc#{t1ext}"
      safe_symlink(t1cachename,t1sym)
      return false unless validate_minc_file(t1sym)

      if file0[:multispectral] || file0[:spectral_mask]
        if t2_id
          t2cachefile = Userfile.find(t2_id)
          t2cachefile.sync_to_cache
          t2cachename = t2cachefile.cache_full_path.to_s
          t2ext = t2cachename.match(/.gz$/i) ? ".gz" : ""
          t2sym = "#{mincfiles_dir}/#{prefix}_#{dsid}_t2.mnc#{t2ext}"
          safe_symlink(t2cachename,t2sym)
          return false unless validate_minc_file(t2sym)
        end

        if pd_id
          pdcachefile = Userfile.find(pd_id)
          pdcachefile.sync_to_cache
          pdcachename = pdcachefile.cache_full_path.to_s
          pdext = pdcachename.match(/.gz$/i) ? ".gz" : ""
          pdsym = "#{mincfiles_dir}/#{prefix}_#{dsid}_pd.mnc#{pdext}"
          safe_symlink(pdcachename,pdsym)
          return false unless validate_minc_file(pdsym)
        end

        if mk_id
          mkcachefile = Userfile.find(mk_id)
          mkcachefile.sync_to_cache
          mkcachename = mkcachefile.cache_full_path.to_s
          mkext = mkcachename.match(/.gz$/i) ? ".gz" : ""
          mksym = "#{mincfiles_dir}/#{prefix}_#{dsid}_mask.mnc#{mkext}"
          safe_symlink(mkcachename,mksym)
          return false unless validate_minc_file(mksym)
        end
      end # if multispectral or spectral_mask
    end # MODE B

    true
  end

  def job_walltime_estimate #:nodoc:
    7.hours # 4.5 normally
  end

  def cluster_commands
    params       = self.params        || {}
    file_args    = params[:file_args] || {}

    master_script = [
      "echo =============================",
      "echo Showing ENVIRONMENT",
      "echo =============================",
      "env | sort",
      "echo ''",
      "echo =============================",
      "echo Showing LIMITS",
      "echo =============================",
      "ulimit -a",
      "echo ''"
    ]

    # Compatibility code for pre-existing OLD civet tasks
    if file_args.size == 1 && File.exists?('mincfiles') && ! File.exists?('mincfiles_0')
      File.rename('mincfiles','mincfiles_0')
    end

    # Optimization if only one CIVET, just like the old code
    if file_args.size == 1
      comms = self.cluster_commands_single("0")
      return nil if comms.blank? || comms.empty?
      master_script += comms
      return master_script
    else
      master_script += [
        "echo =============================",
        "echo Starting CIVETs in background",
        "echo =============================",
        "echo ''"
      ]
    end

    # Create a set of separate BASH scripts.
    run_id       = self.run_id
    script_files = {}
    outfiles     = []
    errfiles     = []
    file_args.each_key.sort { |a,b| a.to_i <=> b.to_i }.each do |arg_idx|
      comms = self.cluster_commands_single(arg_idx)
      next if comms.blank? || comms.empty?
      script_file = "civet_commands_#{arg_idx}.sh"
      File.open(script_file,"w") do |fh|
        subscript_coms = "#!/bin/sh\n\n" + comms.join("\n") + "\n"
        script_files[script_file] = subscript_coms
        fh.write(subscript_coms)
      end
      # Append code to invoke them in the master script, in background.
      # Redirects the STDOUT and STDERR separately.
      outfile = "civet_#{arg_idx}_#{run_id}.out"
      errfile = "civet_#{arg_idx}_#{run_id}.err"
      master_script += [
        "echo Starting CIVET '##{arg_idx}' in background...",
        "/bin/bash #{script_file} > #{outfile} 2> #{errfile} &",
        ""
      ]
      outfiles << outfile
      errfiles << errfile
    end

    return nil if script_files.empty? # nothing to run?!?

    # Epilogue of the master script.
    master_script += [
      "echo ''",
      "echo Waiting for CIVETs to complete, at `date`",
      "wait",
      "echo All CIVETs are done, at `date`",
      "echo ''",
      "echo Compiling STDOUTs...",
      "cat #{outfiles.join(" ")}",
      "echo ''",
      "echo Compiling STDERRs...",
      "cat #{errfiles.join(" ")} 1>&2",
      "echo ''",
      "echo All done",
      "",
      "exit 0",
      ""
    ]

    master_script += [
      "",
      "# ------------------------------------------------------",
      "# For information, here's the content of the sub-scripts",
      "# ------------------------------------------------------",
      "",
    ]

    script_files.each do |sf,coms|
      master_script += [
        "",
        "# --- SUB SCRIPT: #{sf} ---",
        "",
        coms
      ]
    end

    master_script
  end

  def cluster_commands_single(arg_idx) #:nodoc:
    params = self.params
    file0  = params[:file_args][arg_idx] # we require this single entry for info on the data files

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

    reset_from = params[:reset_from]
    if ! reset_from.blank?
      cb_error "Internal error: value for 'reset_from' is not a proper identifier?" unless reset_from =~ /^\w+$/;
      args += "-reset-from #{reset_from} "
    end

    mincfiles_dir = "mincfiles_#{arg_idx}"
    civet_command = "CIVET_Processing_Pipeline -prefix #{prefix} -source #{mincfiles_dir} -target civet_out -spawn #{args} -run #{dsid}"

    self.addlog("Full CIVET command:\n  #{civet_command.gsub(/ -/, "\n  -")}")

    local_script = [
      "echo ==============================================",
      "echo Starting CIVET '##{arg_idx}' for subject '#{dsid}'",
      "echo ==============================================",
      "echo Command: #{civet_command}",
      "echo ''",
      "echo 1>&2 ==============================================",
      "echo 1>&2 Standard Error of CIVET '##{arg_idx}' for subject '#{dsid}'",
      "echo 1>&2 ==============================================",
      "echo 1>&2 Command: #{civet_command}",
      "echo 1>&2 ''"
    ]

    if fake_id
      local_script << "sleep 20  # For FAKE execution, we replace the command with a delay"
    else
      local_script << civet_command
    end

    local_script
  end

  def save_results
    params       = self.params        || {}
    file_args    = params[:file_args] || {}

    if file_args.size > 1
      self.addlog("Parallel CIVETs processing results (x #{file_args.size}).")
    end

    params.delete(:output_civetcollection_id) # old
    params[:output_civetcollection_ids] = []  # new

    stat_not_ok  = 0
    stat_except  = {}
    first_except = nil
    file_args.each_key.sort { |a,b| a.to_i <=> b.to_i }.each do |arg_idx|
      begin
        stat_not_ok += 1 unless self.save_results_single(arg_idx)
      rescue => ex
        first_except         ||= ex
        stat_except[arg_idx]   = ex
      end
    end

    return true if stat_not_ok == 0 && stat_except.blank?

    if stat_not_ok > 0
      self.addlog("Some sub CIVETs (#{stat_not_ok} of them) failed on cluster.") if file_args.size > 1
      return false unless stat_except.size > 0
    end

    # TODO report each exception if there are many ?
    self.addlog("Some CIVET post processing (#{stat_except.size} of them) crashed. Raising the first exception.")
    raise first_except

  end

  def save_results_single(arg_idx) #:nodoc:
    params           = self.params
    file0            = params[:file_args][arg_idx] # we require this single entry for info on the data files

    dsid             = file0[:dsid]   || "unkdsid2"
    data_provider_id = params[:data_provider_id]

    self.addlog("Processing results for CIVET #{arg_idx} '#{dsid}'.")

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

    # Where we find this subject's results
    out_dsid = "civet_out/#{dsid}"

    # Let's make sure it ran OK, test #1
    unless File.directory?(out_dsid)
      self.addlog("Error: this CIVET run did not complete successfully.")
      self.addlog("We couldn't find the result subdirectory '#{out_dsid}' !")
      return false # Failed On Cluster
    end

    # Next block commented-out until we find a better
    # criterion for detecting failed tasks.

    # Let's make sure it ran OK, test #2
    logfiles = Dir.entries("#{out_dsid}/logs")
    running  = logfiles.select { |lf| lf =~ /\.(running|lock)$/i }
    unless running.empty?
      self.addlog("Error: it seems this CIVET run is still processing!")
      self.addlog("We found these files in 'logs' : #{running.sort.join(', ')}")
      self.addlog("Trigger the recovery code to force a cleanup and a try again.")
      return false # Failed On Cluster
    end
    badnews  = logfiles.select { |lf| lf =~ /\.(fail(ed)?)$/i }
    unless badnews.empty?
      failed_t1_trigger = "#{dsid}_nuc_t1_native.failed"
      if badnews.include?(failed_t1_trigger)
         self.addlog("Error: it seems this CIVET run could not process your T1 file!")
         self.addlog("We found this file in 'logs' : #{failed_t1_trigger}")
         self.addlog("The input file is probably not a proper MINC file, there's not much we can do.")
         return false # Failed On Cluster
      end
      self.addlog("Warning: not all subtasks of this CIVET completed successfully.")
      self.addlog("We found these files in 'logs' : #{badnews.sort.join(', ')}")
      self.addlog("This result set might therefore be only partial, but we'll proceed in saving it.")
    end

    # Create new CivetCollection
    out_name = output_name_from_pattern(file0[:t1_name],arg_idx)
    civetresult = safe_userfile_find_or_new(CivetCollection,
      :name             => out_name,
      :data_provider_id => data_provider_id,
      :task             => "Civet"
    )
    unless civetresult.save
      cb_error "Could not save back result file '#{civetresult.name}'."
    end

    # Record collection's ID in task's params # NEW, a list!
    params[:output_civetcollection_ids] << civetresult.id

    # Move or copy some useful files into the collection before creating it.
    FileUtils.cp("civet_out/References.txt",    "#{out_dsid}/References.txt")                     rescue true
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

  def recover_from_cluster_failure
    params       = self.params        || {}
    file_args    = params[:file_args] || {}

    success = true
    file_args.each_key.sort { |a,b| a.to_i <=> b.to_i }.each do |arg_idx|
      success &&= self.recover_from_cluster_failure_single(arg_idx)
    end
    return success
  end

  # Overrides the placeholder method in the module RecoverableTask
  def recover_from_cluster_failure_single(arg_idx) #:nodoc:
    params       = self.params || {}
    file0        = params[:file_args][arg_idx] # we require this single entry for info on the data files
    prefix       = file0[:prefix] || "unkpref2"
    dsid         = file0[:dsid]   || "unkdsid2"

    # Where we find this subject's results
    out_dsid = "civet_out/#{dsid}"

    logfiles = Dir.entries("#{out_dsid}/logs")
    badnews  = logfiles.select { |lf| lf =~ /\.(fail(ed)?|running|lock)$/i }
    if badnews.empty?
      self.addlog("No 'failed' files found in logs.")
    else
      self.addlog("Removing these files in 'logs' : #{badnews.sort.join(', ')}")
      badnews.each { |bn| File.unlink("#{out_dsid}/logs/#{bn}") rescue true }
    end

    true
  end

  private

  # My old convention was '1' for true, "" for false;
  # the new form helpers send '1' for true and '0' for false.
  def mybool(value) #:nodoc:
    return false if value.blank?
    return false if value.is_a?(String)  and value == "0"
    return false if value.is_a?(Numeric) and value == 0
    return true
  end

  # Makes a quick check to ensure the input files
  # are really MINC files.
  def validate_minc_file(path) #:nodoc:
    unless params[:fake_run_civetcollection_id].blank?
      return true # no validation necessary in test 'fake' mode.
    end
    outerr = self.tool_config_system("mincinfo #{path} 2>&1")
    out    = outerr[0]
    base = File.basename(path)
    if File.symlink?(path)
      base = File.basename(File.readlink(path)) rescue base
    end
    if out !~ /^file: /m
       self.addlog("Error: it seems one of the input file '#{base}' we prepared is not a MINC file?!?")
       self.addlog("Output of 'mincinfo':\n#{out}") if ! out.blank?
       return false
    end
    true
  end

  # Creates the output filename based on the pattern
  # provided by the user.
  def output_name_from_pattern(t1name,arg_idx)
    file0        = params[:file_args][arg_idx] # we require this single entry for info on the data files
    prefix       = file0[:prefix] || "unkpref3"
    dsid         = file0[:dsid]   || "unkdsid3"

    pattern = self.params[:output_filename_pattern] || ""
    pattern.strip!
    pattern = '{subject}-{cluster}-{task_id}-{run_number}' if pattern.blank?

    # Create standard keywords
    now = Time.zone.now
    components = {
      "date"       => now.strftime("%Y-%m-%d"),
      "time"       => now.strftime("%H:%M:%S"),
      "task_id"    => self.id.to_s,
      "run_number" => self.run_number.to_s,
      "cluster"    => self.bourreau.name,
      "subject"    => dsid,
      "prefix"     => prefix
    }

    # Add {1}, {2} etc keywords from t1 name
    t1_comps = t1name.split(/([a-z0-9]+)/i)
    1.step(t1_comps.size-1,2) do |i|
      keyword = "#{(i-1)/2+1}"
      components[keyword] = t1_comps[i]
    end

    # Create new basename
    final = pattern.pattern_substitute(components) # in cbrain_extensions.rb

    # Validate it
    cb_error "Pattern for new filename produces an invalid filename: '#{final}'." unless
      Userfile.is_legal_filename?(final)

    return final
  end

end

