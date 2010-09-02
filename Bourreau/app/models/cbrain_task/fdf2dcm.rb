
#
# CBRAIN Project
#
# ClusterTask Model Fdf2dcm
#
# Original author:Ronghai Tu
#
# $Id$
#

# A subclass of CbrainTask::ClusterTask to run Fdf2dcm.
class CbrainTask::Fdf2dcm < ClusterTask

  Revision_info="$Id$"

  def setup #:nodoc:
    params       = self.params
    fdf_colid    = params[:fdf_colid] # the ID of a FDF FileCollection
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
    params        = self.params
    fs_verbose    = params[:verbose].blank? ? 0:1 
    if fs_verbose == 1
      fs_option   = "-V"    
    else
      fs_option   = ""
    end  
    [
      "fdf2dcm #{fs_option} fdf_col",
      "mv fdf_col/*.dcm results",
    ]
  end
  
  def save_results #:nodoc:
    params       = self.params
    fdf_colid    = params[:fdf_colid] # the ID of a FileCollection
    fdf_col      = Userfile.find(fdf_colid)
    user_id      = self.user_id
    group_id     = fdf_col.group_id

    io = IO.popen("find results -type f -name \"*.dcm\" -print","r") 
                  
    numfail =  0
    numok   =  0

    dcmfiles = []
    io.each_line do |file| 
        file = file.sub(/\n$/,"")
        basename = File.basename(file)
        
        dcmfile  = safe_userfile_find_or_new(SingleFile,
          :name             => basename,
          :user_id          => user_id,
          :group_id         => group_id,
          :data_provider_id => params[:data_provider_id],
          :task             => "Fdf2dcm"
        )

        dcmfile.cache_copy_from_local_file(file)                
        if dcmfile.save
          dcmfile.move_to_child_of(fdf_col)
          numok += 1
          if basename.match(/\.dcm/)
            self.addlog("Saved new Dicom file #{basename}")
          end
          dcmfiles << dcmfile
        else
          numfail += 1
          self.addlog("Could not save back converted file '#{basename}'.")
        end
      
    end

    io.close
    params[:created_dcmfile_ids] = dcmfiles.map &:id
    self.addlog_to_userfiles_these_created_these([fdf_col],dcmfiles)

    return true if numok > 0 && numfail == 0
    false
  ensure
    if io
      io.close rescue true
    end
  end
  # Todo: implement the restartable and recoverable ability
  
end

