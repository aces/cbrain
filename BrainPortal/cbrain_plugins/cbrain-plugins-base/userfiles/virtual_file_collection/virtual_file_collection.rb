
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# This file collection is collection of other Userfiles or Collections
# It is implemented using soft links
# two level collections are forbidden to prevent recursion or other issues
class VirtualFileCollection < FileCollection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  CSV_BASENAME = "_virtual_file_collection.cbcsv"
  # todo. add .bidsignore file, otherwise bids validation. Or we can allow CBRAIN filenames starting with dot

  CBRAIN_ARCHIVE_CONTENT_BASENAME = nil


  reset_viewers # we opted to ignore superclass viewers rather than adjust them
  has_viewer :name => 'Virtual File Collection', :partial => :file_collection , :if => :is_locally_synced?

  def self.pretty_type #:nodoc:
    "Virtual File Collection"
  end


  def set_size!
    self.size, self.num_files = Rails.cache.fetch("VirtualFileCollection_#{self.id || "#{current_user.id}_#{self.data_provider_id}_#{self.name}"}#size", expires_in: 3.minutes) do
      userfiles = self.get_userfiles
      [userfiles.sum(&:size), userfiles.sum(&:num_files)]
    end
    self.assign_attributes(size: self.size , num_files: self.num_files) if self.id
    true
  end

  # Sync the VirtualFileCollection, with the files too
  def sync_to_cache(deep=true) #:nodoc:
    syncstat = self.local_sync_status(:refresh)
    return true if syncstat && syncstat.status == 'InSync'
    super()
    if deep && ! self.archived?
      self.sync_files
      self.update_cache_symlinks
    end
    @cbfl = files= nil # flush internal cache
    true
  end

  # Invokes the local sync_to_cache with deep=false; this means the
  # constitute FileCollection are not synchronized and symlinks not created.
  # This method is used by FileCollection when archiving or unarchiving.
  def sync_to_cache_for_archiving
    result = sync_to_cache(false)
    self.erase_cache_symlinks rescue nil
    result
  end

  # When syncing to the provider, we locally erase
  # the symlinks, because they make no sense outside
  # of the local Rails app.
  # FIXME: this method has a slight race condition,
  # after syncing to the provider we recreate the
  # symlinks, but if another program tries to access
  # them during that time they might not yet be there.
  def sync_to_provider #:nodoc:
    self.cache_writehandle do # when the block ends, it will trigger the provider upload
      self.erase_cache_symlinks unless self.archived?
    end
    self.make_cache_symlinks unless self.archived?
    true
  end

  # Sets the set of FileCollections that constitute VirtualFileCollection.
  # The CSV file inside the study will be created/updated,
  # as well as all the symbolic links. The content
  # is NOT synced to the provider side.
  def set_virtual_file_collection(userfiles)
    cb_error "Multi layer collections are not supported." if userfiles.any? { |f| f.is_a?(VirtualFileCollection) || f.is_a?(CivetVirtualStudy) }

    # Prepare CSV content
    content     = CbrainFileList.create_csv_file_from_userfiles(userfiles)

    # This optimize so we don't reload the content for making the symlinks
    @cbfl = CbrainFileList.new
    @cbfl.load_from_content(content)
    @files = nil

    # Write CSV content to the interal CSV file
    self.cache_prepare
    Dir.mkdir(self.cache_full_path) unless Dir.exist?(self.cache_full_path)
    File.write(csv_cache_full_path.to_s, content)
    self.update_cache_symlinks
    self.cache_is_newer
  end

  # List linked files or directories, as if present directly
  def list_linked_files(dir=:all, allowed_types = :regular)
    if allowed_types.is_a? Array
      types = allowed_types.dup
    else
      types = [allowed_types]
    end
    types.map!(&:to_sym)
    types << :file if types.delete(:regular)

    # for combination of :top and :directory file type data are maid up,
    # to avoid running file stats command which should not affect file browsing
    # alternatively, new option(s) can be added to list_files/cache_collection_index,
    # or new dir_info method
    if (dir == :top || dir == '.')
      cloned_files = self.list_files(:top, :link).cb_deep_clone   # no altering the cache of list_files methods
      userfiles_by_name = self.get_userfiles.index_by(&:name)
      return cloned_files.filter_map do |file|
        fname      = file.name.split('/')[1]   # gets basename
        userfile   = userfiles_by_name[fname]
        if types.include?(:directory) &&  userfile.is_a?(FileCollection)
          file.symbolic_type = :directory
          file.userfile = userfile
          # binding.pry
          file
        elsif   types.include?(:file) && userfile.is_a?(SingleFile)
          file = userfile.list_files.first.clone
          file&.name  = self.name + '/' + fname
          file&.symbolic_type = :regular
          file.userfile = userfile
          # binding.pry
          file
        end
      end
    end

    userfiles = self.get_userfiles

    if dir.is_a? String
      name, dir = dir.split '/'
      dir |= '.'
      userfiles = userfiles.select { |x| x.name == name }
    end

    userfiles.map do |userfile|
      userfile.list_files(dir, allowed_types).each do |f|
        f.name = self.name + '/' + f.name
      end
      f.userfile = userfile
    end.flatten
  end

  # todo - remove unless needed for creation?
  # def validate_componets
  #   ufiles = self.get_userfiles
  #   error "Nested Virtual Collection" if ufile.is_a?(VirtualFileCollection) || ufile.is_a?(CivetVirtualStudy) || ufile.type.lower.include?('virtual')
  # end

  # Returns the files IDs
  def get_ids
    self.get_userfiles.map(&:id)
  end

  # Returns the list of files in the internal CbrainFileList
  # The list is cached internally and access control is applied
  # based on the owner of the VirtualFileCollection.
  def get_userfiles #:nodoc:

    if @cbfl.blank?
      @cbfl = CbrainFileList.new
      file_content = File.read(csv_cache_full_path.to_s)
      @cbfl.load_from_content(file_content)
    end

    @files ||= @cbfl.userfiles_accessible_by_user!(self.user).compact
    file_names = @files.map(&:name)
    dup_names = file_names.select { |name| file_names.count(name) >1 }.uniq
    cb_error "Virtual file collection contains duplicate filenames #{dup_names.join(',')}" if dup_names.present?
    @files.each do |f|
      cb_error "Nested virtual file collections are not supported, remove file with id #{f.id}" if   (
        f.is_a?(VirtualFileCollection)     ||
        f.is_a?(CivetVirtualStudy)         ||
        f.type.downcase.include?('virtual')
      )
    end
  end



  #====================================================================
  # Support methods, not part of this model's API.
  #====================================================================

  protected

  # Synchronize each file
  def sync_files #:nodoc:
    self.get_userfiles.each { |uf| uf.sync_to_cache }
  end

  # Clean up ALL symbolic links
  def erase_cache_symlinks #:nodoc:
    Dir.chdir(self.cache_full_path) do
      Dir.glob('*').each do |entry|
        # FIXME how to only erase symlinks that points to a CBRAIN cache or local DP?
        # Parsing the value of the symlink is tricky...
        File.unlink(entry) if File.symlink?(entry)
      end
    end
  end

  # This cleans up any old symbolic links, then recreates them.
  # Note that this does not sync the files themselves.
  def update_cache_symlinks #:nodoc:
    self.erase_cache_symlinks
    self.make_cache_symlinks
  end

  # Create symbolic links in cache for each element of the virtual collection
  # Note that this does not sync the files themselves.
  def make_cache_symlinks #:nodoc:
    self.get_userfiles.each do |uf|
      link_value = uf.cache_full_path
      link_path  = self.cache_full_path + link_value.basename
      File.unlink(link_path) if File.symlink?(link_path) && File.readlink(link_path) != link_value
      File.symlink(link_value, link_path) unless File.exist?(link_path)
    end
  end

  def csv_cache_full_path #:nodoc:
    self.cache_full_path + CSV_BASENAME
  end

end
