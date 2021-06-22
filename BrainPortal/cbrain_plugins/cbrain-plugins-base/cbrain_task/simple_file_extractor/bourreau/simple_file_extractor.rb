
#
# CBRAIN Project
#
# Copyright (C) 2008-2021
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

# A subclass of CbrainTask::ClusterTask to run SimpleFileExtractor.
class CbrainTask::SimpleFileExtractor < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    params       = self.params
    ids          = params[:interface_userfile_ids]

    # DP statistics
    dp_counts = Userfile.where(:id => ids).group(:data_provider_id).count
    dp_files  = Userfile.where(:id => ids).group(:data_provider_id).sum(:num_files)
    dp_sizes  = Userfile.where(:id => ids).group(:data_provider_id).sum(:size)
    self.addlog("DataProvider storage summary:")
    dp_counts.each do |dp_id,count|
      dp        = DataProvider.find(dp_id)
      sum_files = dp_files[dp_id]
      sum_size  = dp_sizes[dp_id]
      self.addlog("DataProvider '#{dp.name}': #{count} entries, #{sum_files} files, #{sum_size} bytes")
    end

    # Verify data providers
    ok  = true
    dps = DataProvider.where(:id => dp_counts.keys).to_a
    dps.each do |dp|
      next if dp.is_fast_syncing?
      self.addlog("Error: DataProvider '#{dp.name}' is not a local storage.")
      ok = false
    end
    return false if ! ok

    # Sync input files
    self.addlog "Synchronizing #{ids.size} input collections; messages below will report progress only once per 10 minutes)"
    start_sync   = 1.day.ago
    tot_files    = 0
    tot_size     = 0
    ids.each_with_index do |id,i|
      userfile=FileCollection.find(id)
      if Time.now - start_sync > 10.minutes # prints a message every ten minutes
        self.addlog("Synchronizing collection #{i+1}/#{ids.size}: \"#{userfile.name}\"")
        start_sync = Time.now
      end
      userfile.sync_to_cache
      tot_files += userfile.num_files
      tot_size  += userfile.size
    end

    self.addlog "Finished synchronizing #{tot_size} bytes in #{tot_files} files"

    if File.directory?("extracted")
      self.addlog("Warning: this task's work directory already contains some extracted files from a previous run. The final result will contain these files too.")
    end

    safe_mkdir("extracted",0700)

    true
  end

  # This task does not submit anything on the cluster
  def cluster_commands #:nodoc:
    nil
  end

  def save_results #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids]

    # Main inputs
    patterns  = patterns_as_array(params[:patterns].presence || {})
    file_cols = FileCollection.where(:id => ids).to_a

    # Error and warning helpers
    error_examples = {}
    error_counts   = {}

    log_it = ->(message,pat,userfile,extpath) {
      extpath &&= extpath.sub((userfile.cache_full_path.parent.to_s+"/"),"")
      error_examples[message] ||= (
        "Pattern: '#{pat}', Collection #{userfile.id} '#{userfile.name}'" +
        (extpath.blank? ? "" : ", Matched extraction file: '#{extpath}'")
      )
      error_counts[message] ||= 0
      error_counts[message]  += 1
    }

    # Main loop for extracting stuff
    self.addlog "Extracting files; messages below will report progress only once per 10 minutes"

    start_extract = 1.day.ago
    file_cols.each_with_index do |userfile,i|

      # Prints a progress message every ten minutes
      if Time.now - start_extract > 10.minutes
        self.addlog("Extracting from collection ##{i+1}/#{file_cols.size}: \"#{userfile.name}\"")
        start_extract = Time.now
      end

      cache_path   = userfile.cache_full_path
      parent_cpath = cache_path.parent
      patterns.each_with_index do |pat,patidx|
        pat = Pathname.new(pat).cleanpath
        # Quick safety check just like in after_form on portal side
        cb_error "Wrong pattern encountered: #{pat}" if
          (! pat.relative?) || (! pat.to_s.index('/')) || (pat.to_s.start_with? "../")
        path_pattern = parent_cpath + pat
        globbed_paths=Dir.glob(path_pattern.to_s)
        if globbed_paths.empty?
          log_it.("No files matched pattern ##{patidx}", pat, userfile, nil)
          next
        end
        globbed_paths.each do |filepath|
          filepath = File.realpath(filepath) rescue nil
          if ! filepath
            log_it.("Globbing through missing filesystem entries", pat, userfile, filepath)
            next
          end
          if ! filepath.start_with?(cache_path.to_s)
            log_it.("Extraction outside collection", pat, userfile, filepath)
            next
          end
          if File.symlink?(filepath)
            log_it.("Trying to extract a symbolic link", pat, userfile, filepath)
            next
          end
          if ! File.file?(filepath)
            log_it.("Trying to extract a non regular file", pat, userfile, filepath)
            next
          end
          basename = File.basename(filepath)
          if File.file?("extracted/#{basename}")
            log_it.("Trying to extract a file with a name matching something already extracted", pat, userfile, filepath)
            next
          end

          # Make the copy
          system "cp", "#{filepath}", "extracted/#{basename}" # no .bash_escape because no bash subshell
          status = $? # a Process::Status object
          if status.signaled?
            self.addlog("Error copying file '#{basename}': got signal #{status.termsig || 'unknown'}. This is fatal.")
            return false
          end
          if ! status.success?
            self.addlog("Error copying file '#{basename}'. Exit code: #{status.exitstatus || 'unknown'}. This is fatal.")
            return false
          end

        end # each globbed file
      end # each pattern
    end # each FileCollection

    self.addlog "Finished extracting from #{file_cols.count} inputs"

    # Log warnings and errors
    if error_examples.present?
      self.addlog "Some errors or warnings occurred; a count and a single example is given below."
    end
    error_examples.keys.each do |message|
      count   = error_counts[message]
      example = error_examples[message]
      self.addlog "#{count}x : #{message}; Example: #{example}"
    end

    # Save final output
    out_name = params[:output_file_name] + "-" + self.run_id
    self.addlog("Saving extracted collection #{out_name}")
    output_file = safe_userfile_find_or_new(FileCollection, :name => out_name)
    output_file.save!
    params[:output_file_id] = output_file.id
    self.addlog("Adding content to collection #{out_name}")
    output_file.cache_copy_from_local_file("extracted")

    # Log creation of output
    self.addlog_to_userfiles_created( output_file )

    true
  end

  # Add here the optional error-recovery and restarting
  # methods described in the documentation if you want your
  # task to have such capabilities. See the methods
  # recover_from_setup_failure(), restart_at_setup() and
  # friends, described in the CbrainTask Programmer Guide.

end

