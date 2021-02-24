
#
# CBRAIN Project
#
# Copyright (C) 2008-2020
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

# A stupid class to provide methods to cache
# the browsing results of a data provider into
# a file in /tmp ; not OO at all
#
# Note: this entire class should be re-engineered to use Rails.cache
class BrowseProviderFileCaching

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Contacts the +provider+ side with provider_list_all(as_user,browse_path) and
  # caches the resulting array of FileInfo objects for 60 seconds.
  # Returns that array. If refresh is set to true, it will force the
  # refresh of the array, otherwise any array that was generated less
  # than 60 seconds ago is returned again.
  def self.get_recent_provider_list_all(provider, as_user, browse_path = nil, refresh = false) #:nodoc:

    refresh = false if refresh.blank? || refresh.to_s == 'false'

    # Check to see if we can simply reload the cached copy
    cache_file = self.cache_file(provider, as_user, browse_path)
    if ! refresh && File.exist?(cache_file) && File.mtime(cache_file) > 60.seconds.ago
       filelisttext = File.read(cache_file)
       fileinfolist = YAML.load(filelisttext)
       return fileinfolist
    end

    # Get info from provider
    fileinfolist = provider.provider_list_all(as_user, browse_path)

    # Write a new cached copy
    save_cache(provider, as_user, browse_path, fileinfolist)

    # Return it
    fileinfolist
  end

  # Saves the array of FileInfo object in a file in /tmp. See
  # also the method cache_file for the file's name.
  def self.save_cache(provider, user, browse_path, fileinfolist) #:nodoc:
    cache_file = self.cache_file(provider, user, browse_path)
    tmpcachefile = cache_file + ".#{Process.pid}.tmp";
    File.open(tmpcachefile,"w") do |fh|
       fh.write(YAML.dump(fileinfolist))
    end
    File.rename(tmpcachefile,cache_file) rescue true  # crush it
  end

  # Clear the cache file.
  def self.clear_cache(provider, user, browse_path) #:nodoc:
    cache_file = self.cache_file(provider, user, browse_path)
    File.unlink(cache_file) rescue true
  end

  private

  # Generates a file name for a cache file; the name is
  # specific to both the provider and the user accessing it.
  def self.cache_file(provider, user, browse_path) #:nodoc:
    pathkey = browse_path.presence || '.'
    pathkey = pathkey.gsub(/[^a-zA-Z0-9_\.]/) { |c| c.each_byte.map { |i| sprintf "%%%2.2x",i }.join }
    cache_file = "/tmp/dp_cache_list_all_#{user.id}.#{provider.id}-#{pathkey}"
    cache_file
  end

end

