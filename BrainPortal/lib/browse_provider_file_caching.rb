
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
# a file in /tmp
#
# Note: this entire class should be re-engineered to use Rails.cache
class BrowseProviderFileCaching

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Contacts the +provider+ side with provider_list_all(as_user) and
  # caches the resulting array of FileInfo objects for 60 seconds.
  # Returns that array. If refresh is set to true, it will force the
  # refresh of the array, otherwise any array that was generated less
  # than 60 seconds ago is returned again.
  def self.get_recent_provider_list_all(provider, as_user = current_user, refresh = false) #:nodoc:

    refresh = false if refresh.blank? || refresh.to_s == 'false'

    # Check to see if we can simply reload the cached copy
    cache_file = self.cache_file(as_user, provider)
    if ! refresh && File.exist?(cache_file) && File.mtime(cache_file) > 60.seconds.ago
       filelisttext = File.read(cache_file)
       fileinfolist = YAML.load(filelisttext)
       return fileinfolist
    end

    # Get info from provider
    fileinfolist = provider.provider_list_all(as_user)

    # Write a new cached copy
    save_cache(as_user, provider, fileinfolist)

    # Return it
    fileinfolist
  end

  # Saves the array of FileInfo object in a file in /tmp. See
  # also the method cache_file for the file's name.
  def self.save_cache(user, provider, fileinfolist) #:nodoc:
    cache_file = self.cache_file(user, provider)
    tmpcachefile = cache_file + ".#{Process.pid}.tmp";
    File.open(tmpcachefile,"w") do |fh|
       fh.write(YAML.dump(fileinfolist))
    end
    File.rename(tmpcachefile,cache_file) rescue true  # crush it
  end

  # Clear the cache file.
  def self.clear_cache(user, provider) #:nodoc:
    cache_file = self.cache_file(user, provider)
    File.unlink(cache_file) rescue true
  end

  private

  # Generates a file name for a cache file; the name is
  # specific to both the provider and the user accessing it.
  def self.cache_file(user, provider) #:nodoc:
    cache_file = "/tmp/dp_cache_list_all_#{user.id}.#{provider.id}"
    cache_file
  end

end

