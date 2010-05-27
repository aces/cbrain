#
# CBRAIN Project
#
# CbrainTask subclass for running dicom2hrrt
#
# Original author: Anton Zoubarev
# Template author: Pierre Rioux
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run dicom2hrrt.
class CbrainTask::Dicom2hrrt < CbrainTask::ClusterTask

  Revision_info="$Id$"

  def setup #:nodoc:
    begin
      params[:data_provider_id] ||= collection.data_provider.id
    
      collection_id = self.params[:dicom_collection_id]
      collection    = Userfile.find(collection_id)

      unless collection && collection.is_a?(FileCollection)
        self.addlog("Could not find active record entry for file collection #{collection_id}")
        return false
      end

      collection.sync_to_cache
      File.symlink(collection.cache_full_path.to_s,"input")

      Dir.mkdir("output",0700)
    rescue => e
      self.addlog("An exception was raised during setup of DicomToHRRT task: #{e.message}")
      false
    end
    true
  end

  def cluster_commands #:nodoc:
    [
      "dicom2hrrt -i input -o output",
    ]
  end
  
  def save_results #:nodoc:
    begin
      dicom_collection_id = self.params[:dicom_collection_id]
      dicom_collection    = Userfile.find(dicom_collection_id)

      hrrt_collection = FileCollection.new(
          :name             => "#{dicom_collection.name}_#{Time.now.to_i}_HRRT",
          :user_id          => self.user_id,
          :group_id         => dicom_collection.group_id,
          :data_provider_id => self.params[:data_provider_id],
          :task             => "DicomToHRRT"
      )
      hrrt_collection.cache_copy_from_local_file("output")
      hrrt_collection.save!
      hrrt_collection.move_to_child_of(dicom_collection)
      self.addlog("Saved new HRRT file #{basename}")
    rescue => e
      # e.backtrace?
      self.addlog("An exception was raised during save_results stage of DicomToHRRT task: #{e.message}")
      false      
    end
    true
  end

end

