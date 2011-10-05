
class Mp3AudioFile < AudioFile

  Revision_info=CbrainFileRevision[__FILE__]

  has_viewer :partial => :html5_mp3_audio, :if => :is_locally_synced?
  
  def self.pretty_type
    "MP3 Audio File"
  end

  def self.file_name_pattern
    /\.mp3$/i
  end
  
end

