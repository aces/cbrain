
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

require 'fileutils'
require 'find'

#
# This class provides an implementation for a data provider
# where the remote files are not even remote, they are local
# to the currently running rails application. The provider's
# files are stored in the new 'cbrain enhanced
# directory tree'; such a tree stores the file "hello"
# into a relative path like this:
#
#     /root_dir/01/23/45/hello
#
# where +root_dir+ is the data provider's +remote_dir+ (a local
# directory) and the components "01", "23" and "45" are computed
# based on the userfile's ID.
#
# This data provider does not cache anything! The 'remote' files
# are in fact all local, and accesing the 'cached' files mean
# accessing the real provider's files. All methods are adjusted
# so that their behavior is sensible.
#
# For the list of API methods, see the DataProvider superclass.
#
class EnCbrainLocalDataProvider < LocalDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def allow_file_owner_change? #:nodoc:
    true
  end

  def cache_prepare(userfile) #:nodoc:
    SyncStatus.ready_to_modify_cache(userfile) do
      threelevels = cache_subdirs_from_id(userfile.id)
      userdir = Pathname.new(remote_dir)
      level1  = userdir                  + threelevels[0]
      level2  = level1                   + threelevels[1]
      level3  = level2                   + threelevels[2]

      Dir.mkdir(userdir) unless File.directory?(userdir)
      Dir.mkdir(level1)  unless File.directory?(level1)
      Dir.mkdir(level2)  unless File.directory?(level2)
      Dir.mkdir(level3)  unless File.directory?(level3)

      true
    end
  end

  # Returns the real path on the DP, since there is no caching here.
  def cache_full_path(userfile)
    basename  = userfile.name
    threelevels = cache_subdirs_from_id(userfile.id)
    Pathname.new(remote_dir) + threelevels[0] + threelevels[1] + threelevels[2] + basename
  end

  # Will actually not do anything except record that all is 'fine' with the SyncStatus entry of the file.
  def cache_erase(userfile)
    SyncStatus.ready_to_modify_cache(userfile,:destroy) do
      true
    end
  end

  def impl_provider_erase(userfile)  #:nodoc:
    fullpath = cache_full_path(userfile) # actually real path on DP
    parent1  = fullpath.parent
    parent2  = parent1.parent
    parent3  = parent2.parent
    begin
      FileUtils.remove_entry(parent1.to_s, true)
      Dir.rmdir(parent2.to_s)
      Dir.rmdir(parent3.to_s)
    rescue Errno::ENOENT, Errno::ENOTEMPTY
      # It's OK if any of the rmdir fails, and we simply ignore that.
    end
    true
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    oldpath   = cache_full_path(userfile)
    oldparent = oldpath.parent
    newpath   = oldparent + newname
    return false unless FileUtils.move(oldpath.to_s,newpath.to_s)
    true
  end
  
  # this returns the category of the data provider -- used in view for admins
  def self.pretty_category_name
    "Enhanced CBRAIN Types"
  end

  def impl_provider_report #:nodoc:
    issues = []

    # Search the provider's root directory for unknown directories and/or files
    userfile_paths = self.userfiles.map { |u| self.provider_full_path(u).to_s }
    all_paths      = Find.find(remote_dir).reject { |p| File.directory?(p) && ! (Dir.entries(p) - %w{ . .. }).empty? }
    base_regex     = Regexp.new('^' + Regexp.quote(remote_dir) + '/?')
    (all_paths - userfile_paths).each do |unk|
      issues << {
        :type      => :unknown,
        :message   => "Unknown file or directory '#{unk.sub(base_regex, '')}'",
        :severity  => :major,
        :action    => :delete,
        :file_path => unk
      }
    end

    issues + super
  end

  def impl_provider_repair(issue) #:nodoc:
    return super(issue) unless issue[:action] == :delete

    # Remove the file/directory itself
    path = issue[:file_path]
    (File.directory?(path) ? Dir : File).unlink(path)
    path = File.dirname(path)

    # Remove all empty directories up to remote_dir
    while path != remote_dir && (Dir.entries(path) - %w{ . .. }).empty?
      Dir.unlink(path)
      path = File.dirname(path)
    end
  end

end

