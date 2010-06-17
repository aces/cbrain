
#
# CBRAIN Project
#
# CbrainTask subclass
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run minc2jiv.
class CbrainTask::Minc2jiv < CbrainTask::ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  Tmpheader_file  = "in.header"
  Tmprawbyte_file = "in.raw_byte.gz"

  def setup #:nodoc:
    params       = self.params
    mincfile_id  = params[:mincfile_id]
    mincfile     = Userfile.find(mincfile_id)
    unless mincfile
      self.addlog("Could not find active record entry for userfile #{mincfile_id}")
      return false
    end
    unless mincfile.name =~ /\.mnc(\.gz|\.Z)?$/i
      raise "Error: unknown extension for file '#{mincfile.name}' (expected .mnc, .mnc.gz or .mnc.Z)"
    end
    params[:data_provider_id] = mincfile.data_provider_id if params[:data_provider_id].blank?
    mincfile.sync_to_cache
    cachename    = mincfile.cache_full_path.to_s
    if cachename =~ /\.mnc$/i
      safe_symlink(cachename,"in.mnc")
    else
      system("gunzip -c <'#{cachename}' >in.mnc")
    end
    true
  end

  def cluster_commands #:nodoc:
    params       = self.params
    [
      "# The darn quarantine init resets the path",
      "CURPATH=\"$PATH\"",
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "export PATH=\"$PATH:$CURPATH\"",
      "minc2jiv.pl -force -output_path . in.mnc"
    ]
  end

  def save_results #:nodoc:
    params       = self.params
    user_id      = self.user_id

    mincfile_id     = params[:mincfile_id]
    mincfile        = Userfile.find(mincfile_id)
    group_id        = mincfile.group_id

    unless (File.exists?(Tmpheader_file) && File.exists?(Tmprawbyte_file))
      self.addlog("Could not find resultfiles #{Tmpheader_file} && #{Tmprawbyte_file}.")
      return false
    end

    orig_plainbasename = mincfile.name.sub(/\.mnc$/,"")
    numsaves = 0

    headerfile = safe_userfile_find_or_new(SingleFile,
      :name             => orig_plainbasename + ".header",
      :user_id          => user_id,
      :group_id         => group_id,
      :data_provider_id => params[:data_provider_id],
      :task             => "Minc2jiv"
    )
    headerfile.cache_copy_from_local_file(Tmpheader_file)
    if headerfile.save
      numsaves += 1
      headerfile.move_to_child_of(mincfile)
      headerfile.addlog_context(self)
      self.addlog("Saved new header file #{headerfile.name}")
      #self.addlog_to_userfiles_created(headerfile)
      params[:header_id] = headerfile.id
    else
      self.addlog("Could not save back result file '#{headerfile.name}'.")
    end

    rawbytefile = safe_userfile_find_or_new(SingleFile,
      :name             => orig_plainbasename + ".raw_byte.gz",
      :user_id          => user_id,
      :group_id         => group_id,
      :data_provider_id => params[:data_provider_id],
      :task             => "Minc2jiv"
    )
    rawbytefile.cache_copy_from_local_file(Tmprawbyte_file)
    if rawbytefile.save
      numsaves += 1
      rawbytefile.move_to_child_of(mincfile)
      rawbytefile.addlog_context(self)
      self.addlog("Saved new rawbyte file #{rawbytefile.name}")
      #self.addlog_to_userfiles_created(rawbytefile)
      params[:raw_byte_id] = rawbytefile.id
    else
      self.addlog("Could not save back result file '#{rawbytefile.name}'.")
    end

    if numsaves > 0
      #self.addlog_to_userfiles_processed(mincfile)
      self.addlog_to_userfiles_these_created_these([ mincfile ], [ headerfile, rawbytefile ])
    end

    return(numsaves == 2 ? true : false)
  end

  # Cleans output files because minc2jiv.pl doesn't clobber
  def clean_outputs #:nodoc:
    params = self.params
    File.unlink(Tmpheader_file)  rescue true
    File.unlink(Tmprawbyte_file) rescue true
    params.delete(:header_id)
    params.delete(:raw_byte_id)
    true
  end

  def restart_at_setup #:nodoc:
    clean_outputs
  end

  def restart_at_cluster #:nodoc:
    clean_outputs
  end

  def recover_from_cluster_failure #:nodoc:
    clean_outputs
  end

end

