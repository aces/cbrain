
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
    params[:data_provider_id] = mincfile.data_provider.id if params[:data_provider_id].blank?
    mincfile.sync_to_cache
    cachename    = mincfile.cache_full_path.to_s
    if cachename =~ /\.mnc$/i
      File.symlink(cachename,"in.mnc")
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
    tmpheader_file  = "in.header"
    tmprawbyte_file = "in.raw_byte.gz"

    unless (File.exists?(tmpheader_file) && File.exists?(tmprawbyte_file))
      self.addlog("Could not find resultfiles #{tmpheader_file} && #{tmprawbyte_file}.")
      return false
    end

    orig_plainbasename = mincfile.name.sub(/\.mnc$/,"")
    numsaves = 0

    headerfile = SingleFile.new(
      :name             => orig_plainbasename + ".header",
      :user_id          => user_id,
      :group_id         => group_id,
      :data_provider_id => params[:data_provider_id],
      :task             => "Minc2jiv"
    )
    headerfile.cache_copy_from_local_file(tmpheader_file)
    if headerfile.save
      numsaves += 1
      headerfile.move_to_child_of(mincfile)
      headerfile.addlog_context(self)
      self.addlog("Saved new header file #{headerfile.name}")
    else
      self.addlog("Could not save back result file '#{headerfile.name}'.")
    end

    rawbytefile = SingleFile.new(
      :name             => orig_plainbasename + ".raw_byte.gz",
      :user_id          => user_id,
      :group_id         => group_id,
      :data_provider_id => params[:data_provider_id],
      :task             => "Minc2jiv"
    )
    rawbytefile.cache_copy_from_local_file(tmprawbyte_file)
    if rawbytefile.save
      numsaves += 1
      rawbytefile.move_to_child_of(mincfile)
      rawbytefile.addlog_context(self)
      self.addlog("Saved new rawbyte file #{rawbytefile.name}")
    else
      self.addlog("Could not save back result file '#{rawbytefile.name}'.")
    end

    return(numsaves == 2 ? true : false)
  end

end

