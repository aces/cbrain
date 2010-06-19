
#
# CBRAIN Project
#
# CbrainTask subclass for running mincpik
#
# Original author: Angela McCloskey
# Template author: 
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run mincpik.
class CbrainTask::Mincpik < CbrainTask::ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
     params = self.params
     mincfile_id = params[:mincfile_id] 
     mincfile = Userfile.find(mincfile_id)
     unless mincfile
        self.addlog("Could not find active record entry for userfile #{mincfile_id}")
        return false
     end
     mincfile.sync_to_cache
     safe_symlink(mincfile.cache_full_path.to_s, mincfile.name)

     params[:data_provider_id] = mincfile.data_provider_id if params[:data_provider_id].blank?
     
     true
  end

  def cluster_commands #:nodoc:
        params       = self.params

        mincfile_name  = Userfile.find(params[:mincfile_id]).name

        mincpik_args= {}

        slice = params[:slice] ? "-slice #{params[:slice]}" : ""
        scale = params[:scale] ? "-scale #{params[:scale]}" : ""
        width = params[:width] ? "-width #{params[:width]}" : ""
        depth = params[:depth] ? "-depth #{params[:depth]}" : ""
        image_range = (! params[:image_range_1].blank? && ! params[:image_range_2].blank?) ? "-image_range #{params[:image_range_1]} #{params[:image_range_2]}" : ""
        image_color = params[:image_color]? "-lookup -#{params[:image_color]}" : ""
        slicing_options = params[:slicing_options]? "-#{params[:slicing_options]}" : ""

        out_name = params[:out_name]
        self.addlog("Here we go mincpik #{slice} #{scale} #{width} #{depth} #{image_range} #{image_color} #{slicing_options} #{mincfile_name} #{out_name}")        
        
        [
          "source #{CBRAIN::Quarantine_dir}/init.sh",
          "mincpik #{slice} #{scale} #{width} #{depth} #{image_range} #{image_color} #{slicing_options} #{mincfile_name} #{out_name}",
          "true"
        ]
  end
  
  def save_results #:nodoc:
      params       = self.params
      user_id      = self.user_id
      mincfile_id = params[:mincfile_id] 
      mincfile = Userfile.find(mincfile_id)
      group_id = mincfile.group_id
      out_name = params[:out_name]

      unless (File.exists?(out_name))
        self.addlog("Could not find result file #{out_name}.")
        return false
      end

      outfile = safe_userfile_find_or_new(SingleFile,
        :name             => out_name,
        :user_id          => user_id,
        :group_id         => group_id,
        :data_provider_id => params[:data_provider_id],
        :task             => "Mincpik"
      )
      outfile.cache_copy_from_local_file(out_name)

      if outfile.save
        outfile.move_to_child_of(Userfile.find(params[:mincfile_id]))
        self.addlog("Saved new mincpik file #{out_name}")
        params[:outfile_id] = outfile.id
        self.addlog_to_userfiles_these_created_these( [ mincfile ], [ outfile ] )
        return true
      else
        self.addlog("Could not save back result file '#{out_name}'.")
        params.delete(:outfile_id)
        return false
      end
    end

end

