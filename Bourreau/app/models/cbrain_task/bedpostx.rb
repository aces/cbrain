
#
# CBRAIN Project
#
# ClusterTask Model Bedpostx
#
# Original author: Pierre Rioux
#
# $Id$
#

# A subclass of ClusterTask to run Bedpostx.
class CbrainTask::Bedpostx < ClusterTask

  Revision_info="$Id$"

  include RestartableTask
  include RecoverableTask

  # See CbrainTask.txt
  def setup #:nodoc:
    params       = self.params
    input_colid  = params[:interface_userfile_ids][0]
    collection   = FileCollection.find(input_colid)
    collection.sync_to_cache
    safe_symlink(collection.cache_full_path,"input")

    # TODO: replace with a call to program 'bedpostx_datacheck' ?
    expected_input = [ "bvecs", "bvals" ]
    errors = 0
    expected_input.each do |base|
      next if File.exist?("input/#{base}")
      self.addlog("Cannot proceed: we expected to find an entry '#{base}' in the input directory, but it's not there!")
      errors += 1
    end
    return false if errors > 0

    # Setting the data_provider_id here means it persists
    # in the ActiveRecord params structure for later use.
    if params[:data_provider_id].blank?
       params[:data_provider_id] = collection.data_provider.id
    end

    true
  end

  # See CbrainTask.txt
  def cluster_commands #:nodoc:
    params       = self.params
    fibres       = params[:fibres]
    weight       = params[:weight]
    burn_in      = params[:burn_in]
    fibres       = "2"   if fibres.blank?
    weight       = "1"   if weight.blank?
    burn_in      = "100" if burn_in.blank?
    cb_error "Unexpected value '#{fibres}' for number fibres." if fibres.to_s !~ /^\d+(\.\d+)?$/ # TODO real?
    cb_error "Unexpected value '#{weight}' for weight."        if weight.to_s !~ /^\d+(\.\d+)?$/ # TODO real?
    cb_error "Unexpected value '#{burn_in}' for burn_in."      if burn_in.to_s !~ /^\d+$/
    command =  "bedpostx input -n #{fibres} -w #{weight} -b #{burn_in}"
    self.addlog("Command: #{command}")
    [
      command
    ]
  end
  
  # See CbrainTask.txt
  def save_results #:nodoc:
    params       = self.params
    input_colid  = params[:interface_userfile_ids][0]
    collection   = FileCollection.find(input_colid)

    if ! File.exist?("input.bedpostX") || ! File.directory?("input.bedpostX")
      self.addlog("Could not find expected output directory 'input.bedpostX'.")
      return false
    end

    outfile = safe_userfile_find_or_new(FileCollection,
      :name             => "#{collection.name}.#{self.run_id}.bedpostX",
      :data_provider_id => params[:data_provider_id],
      :task             => self.name
    )
    outfile.save!
    outfile.cache_copy_from_local_file("input.bedpostX")
    params[:outfile_id] = outfile.id

    # Log information
    self.addlog_to_userfiles_these_created_these([ collection ],[ outfile ])
    outfile.move_to_child_of(collection)
    self.addlog("Saved new BEDPOSTX result file #{outfile.name}.")
    true
  end

end

