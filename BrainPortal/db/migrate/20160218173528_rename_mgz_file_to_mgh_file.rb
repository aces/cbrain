
# force pre-load of all constants under Userfile
Userfile.nil?

# Just in case the plugin isn't installed.
class MgzFile < SingleFile
end

# Just in case the plugin isn't installed.
class MghFile < SingleFile
end

# In cbrain-plugins-neuro we now have a single MghFile class
# for compressed and uncompressed content.
# This is similar to what we have for NIfTI and MINC.
class RenameMgzFileToMghFile < ActiveRecord::Migration
  def up
    Userfile.where(:type => "MgzFile").update_all(:type => "MghFile")
  end

  def down
    Userfile.where(:type => "MghFile").update_all(:type => "MgzFile")
  end
end
