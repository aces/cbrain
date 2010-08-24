
#
# CBRAIN Project
#
# ClusterTask Model Fdf2sdt
#                 
# Original author:Ronghai Tu
#
# $Id$
#

# A subclass of CbrainTask::ClusterTask to run Fdf2sdt.
# This tool will convert a Fdf FileCollection to one sdt file and spr file
class CbrainTask::Fdf2sdt < ClusterTask

  Revision_info="$Id$"

  # Todo implement restartable and recoverable
  # include RestartableTask # This task is naturally restartable
  # include RecoverableTask # This task is naturally recoverable 

  def setup #:nodoc:
    params       = self.params
    fdf_colid    = params[:fdf_colid] # the ID of a FDF FileCollection
    sdtout       = params[:sdtout] # the sdt and spr file name without extension
    fdf_col      = Userfile.find(fdf_colid)

    unless fdf_col
      self.addlog("Could not find active record entry for Fdf file collection #{fdf_colid}")
      return false
    end

    unless fdf_col.is_a?(FileCollection)
      self.addlog("Error:ActiveRecord entry #{fdf_colid} is not a Fdf file collection.")
      return false
    end

    params[:data_provider_id] = fdf_col.data_provider_id if params[:data_provider_id].blank?

    fdf_col.sync_to_cache
    fdfcache = fdf_col.cache_full_path.to_s
    
    safe_symlink(fdfcache,"fdf_col")
    safe_mkdir("results",0700)

    true
  end

  def cluster_commands #:nodoc:
    params          = self.params
    verbose         = params[:verbose].blank? ? 0:1 
    sdtout          = params[:sdtout]
    if verbose == 0 
      fs_option = ""  # verbose mode off  
    else
      fs_option = "-V"    # verbose mode on
    end
    
    [
      "fdf2sdt #{fs_option} fdf_col #{sdtout}",
      "mv fdf_col/#{sdtout}.* results",
    ]
  end
  
  def save_results #:nodoc:
    params       = self.params
    fdf_colid    = params[:fdf_colid] # the ID of a FileCollection
    fdf_col      = Userfile.find(fdf_colid)
    user_id      = self.user_id
    group_id     = fdf_col.group_id

    io = IO.popen("find results -type f -name \"*.s*\" -print","r") 
                  
    numfail =  0
    numok   =  0

    sdtfiles = []
    io.each_line do |file| 
        file = file.sub(/\n$/,"")
        basename = File.basename(file)
        
        sdtfile  = safe_userfile_find_or_new(SingleFile,
          :name             => basename,
          :user_id          => user_id,
          :group_id         => group_id,
          :data_provider_id => params[:data_provider_id],
          :task             => "Fdf2sdt"
        )

        sdtfile.cache_copy_from_local_file(file)                
        if sdtfile.save
          sdtfile.move_to_child_of(fdf_col)
          numok += 1
          if basename.match(/\.sdt$/)
            self.addlog("Saved new SDT file #{basename}")
          else
            self.addlog("Saved new SPR file #{basename}")
          end
          sdtfiles << sdtfile
        else
          numfail += 1
          self.addlog("Could not save back converted file '#{basename}'.")
        end
      
    end

    io.close
    params[:created_sdtfile_ids] = sdtfiles.map &:id
    self.addlog_to_userfiles_these_created_these([fdf_col],sdtfiles)

    return true if numok > 0 && numfail == 0
    false
  ensure
    io.close if io
  end
  # Todo: implement the restartable and recoverable ability

end                     

