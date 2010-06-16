
#
# CBRAIN Project
#
# CbrainTask subclass
#
# Original author: Mathieu Desrosiers
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run cw5.
class CbrainTask::Cw5 < CbrainTask::ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:

    params      = self.params
    optic_colid = params[:file_ids]  # the ID of a FileCollection
    optic_col   = Userfile.find(optic_colid)

    unless optic_col
      self.addlog("Could not find active record entry for file collection #{optic_colid}")
      return false
    end

    unless optic_col.class.to_s == "FileCollection"
      self.addlog("Error: ActiveRecord entry #{optic_colid} is not a file collection.")
      return false
    end

    optic_col.sync_to_cache
    cachename = optic_col.cache_full_path.to_s
    safe_symlink(cachename,"optic_col")

    params[:data_provider_id] = optic_col.data_provider_id if params[:data_provider_id].blank?

    config_colid = params[:configuration_col_id]  # the ID of a FileCollection
    config_col   = Userfile.find(config_colid)

    unless config_col
      self.addlog("Could not find active record entry for file collection #{config_colid}")
      return false
    end

    unless config_col.class.to_s == "FileCollection"
      self.addlog("Error: ActiveRecord entry #{config_colid} is not a file collection.")
      return false
    end

    config_col.sync_to_cache
    cachename = config_col.cache_full_path.to_s
    safe_symlink(cachename,"config_col")

    probe_id  = params[:probe_id]
    probe_file = Userfile.find(probe_id)
    unless probe_file
      self.addlog("Could not find active record entry for userfile #{probe_id}")
      return false
    end

    probe_file.sync_to_cache
    cachename    = probe_file.cache_full_path.to_s
    safe_symlink(cachename, "probe.mls") #I What the name in a variable instead

    filter_id  = params[:filter_id]
    filter_file = Userfile.find(filter_id)
    unless filter_file
      self.addlog("Could not find active record entry for userfile #{filter_id}")
      return false
    end

    filter_file.sync_to_cache
    cachename    = filter_file.cache_full_path.to_s
    safe_symlink(cachename, "filter.flt") #I What the name in a variable instead

    safe_mkdir("result",0700)

    true
  end

  def cluster_commands #:nodoc:
    params       = self.params

    matlab_command = "/opt/share/matlab-7.2/bin/matlab -nojvm -nodesktop -nodisplay -r \"chdir('result'); addpath('../config_col'); addpath('../optic_col'); "
    cw5_command = ""
    entry_name = ""

    input_files_pattern = File.join('optic_col','**','*_0[A,B,C,D]00000.bin')

    input_files = Dir.glob(input_files_pattern)
    input_files.each do |input_file|

      if entry_name.empty?
        entry_name = File.basename(input_file)
        entry_name = entry_name[0..(entry_name.length)-13]
      end

      out_name = "result/" + File.basename(input_file, ".bin") + ".cw5"
      cw5_command += "cw5filter -o #{out_name} -p probe.mls -f filter.flt #{input_file};\n"
    end

    #grep les ssdcnas
    ssdcna_scripts_pattern = File.join('config_col','**','ssdcna*.m')
    ssdcna_scripts = Dir.glob(ssdcna_scripts_pattern)

    ssdcna_scripts.each do |ssdcna_script|
      ssdcna =  File.basename(ssdcna_script, ".m")

      cw5_command += "#{matlab_command} #{ssdcna} #{entry_name}\" </dev/null \n"
    end

    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "#{cw5_command}"
    ]
  end

  def save_results #:nodoc:
    params      = self.params
    optic_colid = params[:file_ids]  # the ID of a FileCollection
    optic_col   = Userfile.find(optic_colid)
    user_id     = self.user_id

    optic_tarresult = "cw5#{self.object_id}.tar"
    system("tar -cpf #{optic_tarresult} result/*.mat")

    opticresult = safe_userfile_find_or_new(SingleFile,
      :name             => optic_tarresult,
      :user_id          => user_id,
      :group_id         => optic_col.group_id,
      :data_provider_id => params[:data_provider_id],
      :task             => 'CW5'
    )
    opticresult.cache_copy_from_local_file(optic_tarresult)

    if opticresult.save
      opticresult.move_to_child_of(optic_col)
      self.addlog("Saved new cw5 result file #{opticresult.name}.")
      return true
    else
      self.addlog("Could not save back result file '#{opticresult.name}'.")
      return false
    end

   end
end
