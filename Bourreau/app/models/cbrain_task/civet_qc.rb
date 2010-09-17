
#
# CBRAIN Project
#
# CivetQc subclass for running Claude's CIVET QC PIPELINE
#
# Original author: Pierre Rioux
#
# $Id$
#

# A subclass of ClusterTask to run Claude's CIVET QC PIPELINE
class CbrainTask::CivetQc < ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params       = self.params
    user_id      = self.user_id

    # Get the ID of the study; it can be given directly
    # in the params, or indirecly through another task ID
    study_id = params[:study_id]
    if study_id.blank?
      task_id = params[:study_from_task_id]
      task = CbrainTask.find(task_id)
      tparams = task.params
      study_id = tparams[:output_civetstudy_id]
      params[:study_id] = study_id # save back
    end
    study = CivetStudy.find(study_id)
    study.sync_to_cache

    # Find out the subject IDs we have; these are stored in
    # yml files in each CivetCollection subdirectory.
    study_path = study.cache_full_path
    dsid_dirs  = Dir.entries(study_path.to_s).reject do |e|
       e == '.' || e == '..' ||
       !File.directory?( study_path + e ) ||
       !File.exist?( study_path + e + "CBRAIN.params.yml")
    end
    if dsid_dirs.size == 0
      self.addlog("Could not find any CivetCollection with params file?")
      return false
    end

    # Check the params structure for each CIVET run
    prefix = nil
    dsid_dirs.each do |dir|
      ymltext        = File.read("#{study_path}/#{dir}/CBRAIN.params.yml")
      civet_params   = YAML::load(ymltext)
      file_args      = civet_params[:file_args] || { "0" => {} }
      file0          = file_args["0"] || {}

      # Check that the DSID matches the dir name
      civet_dsid     = file0[:dsid] || civet_params[:dsid] || "(unset)"  # NEW || OLD || unset
      if civet_dsid.to_s != dir
        self.addlog("Error: CivetCollection '#{dir}' is for subject id (DSID) '#{civet_dsid}'.")
        return false
      end

      # Check that all prefixes are the same
      civet_prefix   = file0[:prefix] || civet_params[:prefix] || "(unset)"   # NEW || OLD || unset
      prefix       ||= civet_prefix
      if prefix != civet_prefix
        self.addlog("Error: CivetCollection '#{dir}' is for prefix '#{civet_prefix}' while we found others with '#{prefix}'.")
        return false
      end

      # TODO check other params here to make sure everything is consistent?
    end

    # Creates a 'input' directory for mincfiles by linking to
    # all the files in all the 'native/' subdirs.
    safe_mkdir("mincfiles",0700)
    dsid_dirs.each do |dir|
      native = "#{study_path}/#{dir}/native"
      next unless File.exist?(native) && File.directory?(native)
      Dir.foreach(native) do |minc|
        next unless File.file?("#{native}/#{minc}")
        safe_symlink("#{native}/#{minc}","mincfiles/#{minc}") unless File.exist?("mincfiles/#{minc}")
      end
    end

    # Store the list of DSIDs in a hash in the params
    dsid_names = {}  # "Xn" => dsid   where n is some number
    dsid_dirs.each_with_index { |dir,i| dsid_names["X#{i}"] = dir }
    params[:dsid_names] = dsid_names
    params[:prefix]     = prefix

    true
  end

  def cluster_commands #:nodoc:
    params       = self.params
    user_id      = self.user_id

    study_id = params[:study_id]
    study = CivetStudy.find(study_id)
    study_path = study.cache_full_path

    prefix     = params[:prefix]
    dsid_names = params[:dsid_names] # hash, keys are meaningless
    dsids      = dsid_names.values.sort.join(" ")

    civetqc_command = "CIVET_QC_Pipeline -sourcedir mincfiles -targetdir '#{study_path}' -prefix #{prefix} #{dsids}"

    self.addlog("Full CIVET QC command:\n  #{civetqc_command.gsub(/ -/, "\n  -")}")

    return [
      "echo \"\";echo Showing ENVIRONMENT",
      "env | sort",
      "echo \"\";echo Starting CIVET QC",
      "echo Command: #{civetqc_command}",
      "#{civetqc_command}"
    ]

  end
  
  def save_results #:nodoc:
    params       = self.params
    user_id      = self.user_id

    # Check for some common error conditions.
    stderr = File.read(self.stderr_cluster_filename) rescue ""
    if stderr =~ /gnuplot.*command not found/i
      self.addlog("Error: it seems 'gnuplot' is not installed on this cluster. QC report incomplete.")
      return false
    elsif stderr =~ /command not found/i
      self.addlog("Error: it seems some command is not installed on this cluster. QC report incomplete.")
      return false
    end

    # Find study object and mark it as changed.
    study_id = params[:study_id]
    study = CivetStudy.find(study_id)

    # Save back study with QC report in it.
    self.addlog("Syncing study with QC reports back to data provider.")
    study.cache_is_newer
    study.sync_to_provider

    # Log that it was processed
    prefix     = params[:prefix]
    dsid_names = params[:dsid_names] # hash, keys are meaningless
    dsids      = dsid_names.values.sort.join(" ")
    self.addlog_to_userfiles_processed(study, "with prefix '#{prefix}' and subjects '#{dsids}'")

    true
  end

end

