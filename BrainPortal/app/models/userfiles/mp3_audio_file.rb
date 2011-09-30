
class Mp3AudioFile < AudioFile

  Revision_info=CbrainFileRevision[__FILE__]

  has_viewer :html5_mp3_audio
  
  def self.pretty_type
    "MP3 Audio File"
  end

  def self.file_name_pattern
    /\.mp3$/i
  end
  
end

