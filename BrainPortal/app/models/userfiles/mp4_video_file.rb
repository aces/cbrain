
class Mp4VideoFile < VideoFile

  Revision_info=CbrainFileRevision[__FILE__]

  has_viewer :partial => :html5_mp4_video, :if => :is_locally_synced?
  
  def self.pretty_type
    "MP4 Video File"
  end

  def self.file_name_pattern
    /\.mp4$/i
  end
  
end

