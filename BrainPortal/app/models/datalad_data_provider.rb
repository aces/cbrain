
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

class DataladDataProvider < DataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :datalad_repository_url, :datalad_relative_path

  def self.pretty_category_name #:nodoc:
    "DataladProvider"
  end

  # This returns the datalad repository
  # and if not inititalized, created the datalad_repository class from the variables
  def datalad_repo
    return @datalad_repo if @datalad_repo
    @datalad_repo = DataladRepository.new(self.datalad_repository_url,
                                          self.datalad_relative_path,
                                          self.id,
                                          RemoteResource.current_resource.id)
  end

  def is_browsable?(by_user = nil) #:nodoc:
    true
  end

  def allow_file_owner_change? #:nodoc:
    true
  end

  def content_storage_shared_between_users? #:nodoc:
    true
  end

  def is_fast_syncing? #:nodoc:
    false
  end

  def provider_full_path(userfile) #:nodoc: # not sure is needed anymore
    # because this is on the datalad_repository, only the userfile name is needed
    userfile.name
  end

  def impl_is_alive? #:nodoc:
    true
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    src = userfile.name
    dest = cache_full_path(userfile)

    # Prepare receiving area
    mkdir_cache_subdirs(userfile) # DataProvider method core caching subsystem

    datalad_repo.get_files_into_directory(src,dest,cache_rootdir().to_s)

    cb_error "Cannot fetch content of '#{userfile.name}' on Datalad site from '#{datalad_repo.get_url}'." unless File.exists?(dest.to_s)

    true
  end

  def impl_provider_erase(userfile)  #:nodoc:
    cb_error 'Erase not allowed'
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    cb_error 'Rename not allowed'
  end

  def impl_provider_list_all(user = nil) #:nodoc: # user ignored
    provider_readdir("",false)
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    ### Should this be recursive?
    recursive = directory == :all ? true : false
    ### fix the right path name
    directory = directory == :top || directory == :all ? "" : directory
    path_name = Pathname.new(userfile.name)
    path_name = directory != "" ? path_name.join(directory) : path_name

    provider_readdir(path_name,recursive)

  end

  private
  # Low level read of a single directory level. Caches in the Scratch DP.
  # Very inefficient, but the datalad API is slow.
  # Caching information in a json could improve performance, but at the cost of updating dynamically
  def provider_readdir(dirname, recursive=true, allowed_types = [ :regular, :directory]) #:nodoc:

    allowed_types = Array(allowed_types)
    dirname       = dirname.to_s

    # call the datalad repository list_contents to get everything
    list = []

    uid_to_owner = {}
    gid_to_group = {}

    datalad_repo.list_contents(recursive,dirname).each do |fname|
      name = fname[:name]
      size = fname[:size_in_bytes]
      type = fname[:type]

      dl_full_path = datalad_repo.get_full_cache_with_prefix(name)

      # fix type
      type == :file || type == :gitannexlink ? type = :regular : type

      next unless allowed_types.include? type
      next if is_excluded?(name)

      # get stat with lstat
      stat = File.lstat(dl_full_path)

      # Look up user name from uid
      uid        = stat.uid
      owner_name = (uid_to_owner[uid] ||= (Etc.getpwuid(uid).name rescue uid.to_s))

      # Lookup group name from gid
      gid        = stat.gid
      group_name = (gid_to_group[gid] ||= (Etc.getgrgid(gid).name rescue gid.to_s))

      # Create a FileInfo
      fileinfo               = FileInfo.new
      fileinfo.name          = name
      fileinfo.symbolic_type = type
      fileinfo.size          = size
      fileinfo.permissions   = stat.mode
      fileinfo.atime         = stat.atime
      fileinfo.ctime         = stat.ctime
      fileinfo.mtime         = stat.mtime
      fileinfo.uid           = uid
      fileinfo.owner         = owner_name
      fileinfo.gid           = gid
      fileinfo.group         = group_name

      list << fileinfo
    end

    list.sort! { |a,b| a.name <=> b.name }
    list
  end
end

