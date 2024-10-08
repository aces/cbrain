
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

# Wipe old cache entries
#
# Usually started as part of the boot process of a portal
# or Bourreau.
class BackgroundActivity::WipeOldCache < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Creates a scheduled object for cleaning up the local cache.
  # Returns the object.
  # Will not do it if an object already exists that was updated less
  # than 2 hours ago. In that case, returns nil.
  def self.setup!
    # Don't schedule a cleanup if we've had one in the past 2 hours
    return nil if self.where(:remote_resource_id => CBRAIN::SelfRemoteResourceId)
                      .where('updated_at > ?', 2.hours.ago)
                      .exists?

    # Create the scheduled object
    self.new(
      :user_id            => User.admin.id,
      :remote_resource_id => CBRAIN::SelfRemoteResourceId,
      :status             => 'Scheduled',
      :start_at           => Time.now + 60.seconds,
    )
    .configure_for_dynamic_items!
    .save!
  end

  def process(path)  # path is like "101/22/33"
    root = Pathname.new(DataProvider.cache_rootdir)
    full = root + path
    system("chmod","-R","u+rwX",full.to_s)   # uppercase X affects only directories
    FileUtils.remove_entry(full.to_s, true)
    parent1 = full.parent      # "root/101/22"
    parent2 = parent1.parent   # "root/101"
    (Dir.rmdir(parent1.to_s) rescue nil) && (Dir.rmdir(parent2.to_s) rescue nil)
    return [ true, nil ]
  end

  # Scans the filesystem and compares
  # the entries with the DB's Userfile and SyncStatus objects.
  # We select paths that don't match existing userfiles, or
  # path the match userfiles but don't have any SyncStatus
  def prepare_dynamic_items
    all_paths = get_all_paths_in_cache()
    to_remove = paths_to_delete(all_paths)
    self.items = to_remove # empty list will cause object to not save, which is fine
  end

  protected

  # Scan the cache, returns all relative paths "101/23/45" as an array
  def get_all_paths_in_cache
    Dir.chdir(DataProvider.cache_rootdir) do
      # The find command below has been tested on Linux and Mac OS X
      # It MUST generate exactly three levels deep so it can properly
      # infer the original file ID !
      dirlist = []
      IO.popen("find . -mindepth 3 -maxdepth 3 -type d -print","r") { |fh| dirlist = fh.readlines rescue [] }
      dirlist.map do |path|  # path should be  "./01/23/45\n"
        next nil unless path =~ /\A\.\/\d+\/\d+\/\d+\s*\z/ # make sure
        path.strip.sub(/\A\.\//,"") # "01/23/45"
      end.compact
    end
  end

  # Selects which paths to delete out of those returned by get_all_paths_in_cache
  def paths_to_delete(paths)
    uids_seen_in_cache = paths.map { |path| path.gsub(/\D+/,"").to_i(10) }  # [ "00/11/22", ... ] => [ 1122, ...]

    # Might as well clean spurious SyncStatus entries too.
    # These are the ones that say something's in the cache,
    # yet we couldn't find any files on disk.
    rr_id                    = self.remote_resource_id
    supposedly_in_cache      = SyncStatus.where( :remote_resource_id => rr_id, :status => [ 'InSync', 'CacheNewer' ] )
    supposedly_in_cache_uids = supposedly_in_cache.raw_first_column(:userfile_id)
    not_in_cache_uids        = supposedly_in_cache_uids - uids_seen_in_cache
    supposedly_in_cache.where( :userfile_id => not_in_cache_uids ).destroy_all if not_in_cache_uids.present?

    all_uids        = Userfile.pluck(:id).index_by(&:itself)
    all_synced_uids = SyncStatus.where( :remote_resource_id => rr_id ).pluck(:userfile_id).index_by(&:itself)

    paths_to_remove = paths.each_with_index.map do |path,idx|
      uid = uids_seen_in_cache[idx]        # parallel array, transforms "00/11/22" to 1122
      next path if ! all_uids[uid]         # remove path if the userfile doesn't exist at all
      next path if ! all_synced_uids[uid]  # remove path if it's not recorded in SyncStatus
      nil
    end.compact

    paths_to_remove
  end

  def after_last_item
    myself = self.remote_resource
    Message.send_message(User.admin,
      :type          => :system,
      :header        => "Report of cache crud removal on #{myself.is_a?(BrainPortal) ? "Portal" : "Execution Server"} '#{myself.name}'",
      :description   => "These relative paths in the local Data Provider cache were\n" +
                        "removed as there are no longer any userfiles matching them.\n",
      :variable_text => "#{self.items.size} cache subpaths:\n" + self.items.sort
                        .each_slice(10).map { |pp| pp.join(" ") }.join("\n"),
      :critical      => true,
      :send_email    => false
    ) rescue true
  rescue
    nil
  end

end

