
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
class BrowseProviderFileCaching

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # How long we cache the results of provider_list_all();
  BROWSE_CACHE_EXPIRATION = 60.seconds #:nodoc:
  RACE_CONDITION_DELAY    = 10.seconds # Short delay for concurrent threads

  # Contacts the +provider+ side with provider_list_all(as_user, browse_path) and
  # caches the resulting array of FileInfo objects for 60 seconds.
  # Returns that array. If refresh is set to true, it will force the
  # refresh of the array, otherwise any array that was generated less
  # than 60 seconds ago is returned again.
  def self.get_recent_provider_list_all(provider, as_user, browse_path = nil, refresh = false) #:nodoc:

    refresh = false if refresh.blank? || refresh.to_s == 'false'
    key     = dp_cache_key(as_user, provider, browse_path)
    Rails.cache.fetch(key,
                      force:              refresh,
                      expires_in:         BROWSE_CACHE_EXPIRATION,
                      race_condition_ttl: RACE_CONDITION_DELAY) do
      provider.provider_list_all(as_user, browse_path)
    end
  end

  # Clear the provider browse cache.
  def self.clear_cache(user, provider, browse_path = nil) #:nodoc:
    Rails.cache.delete(dp_cache_key(user, provider, browse_path))
  end

  private

  # The cache key, which depends on user, provider and browse path.
  def self.dp_cache_key(user, provider, browse_path) #:nodoc:
    "dp_file_list_#{user.try(:id)}-#{provider.try(:id)}-#{browse_path}"
  end

end

