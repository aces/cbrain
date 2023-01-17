
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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

# Model representing disk quotas
class DiskQuota < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :user_id
  validates_presence_of :data_provider_id
  validates_presence_of :max_bytes
  validates_presence_of :max_files

  belongs_to :user,          :optional => true # the value can be 0 but not nil
  belongs_to :data_provider, :optional => false

  validates_uniqueness_of :user_id, :scope => [ :data_provider_id ]

  CACHED_USAGE_EXPIRATION = 1.minute

  attr_reader :cursize, :curfiles # values are filled when performing a check

  # Returns true if currently, the user specified by +user_id+
  # uses more disk space or more total files on +data_provider_id+ than
  # the quota limit configured by the admin.
  #
  # The quota record for the limits is first looked up specifically for the pair
  # (user, data_provider); if no quota record is found, the pair (0, data_provider)
  # will be fetched instead (meaning a default quota for all users on that DP)
  #
  # Possible returned values:
  # nil              : all is OK
  # :bytes           : disk space is exceeded
  # :files           : number of files is exceeded
  # :bytes_and_files : both are exceeded
  def self.exceeded?(user_id, data_provider_id)
    quota   = self.where(:user_id => user_id, :data_provider_id => data_provider_id).first
    quota ||= self.where(:user_id => 0      , :data_provider_id => data_provider_id).first
    return nil if quota.nil?

    quota.exceeded?(user_id)
  end

  # Same as the 'exceeded?' but raises a CbrainDiskQuotaExceeded
  # exception if the quota is exceeded. Returns nil if everything is ok.
  def self.exceeded!(user_id, data_provider_id)
    return nil if ! self.exceeded?(user_id, data_provider_id)
    raise CbrainDiskQuotaExceeded.new(user_id, data_provider_id)
  end

  # Returns true if currently, the user specified by +user+ (specified by id)
  # uses more disk space or more total files on than configured in the limits
  # of this quota object. Since a quota object can contain '0' for the user attribute
  # (meaning it's a default for all users), a user_id must be given explicitely
  # in argument in that case.
  def exceeded?(user_id = self.user_id)

    return nil if user_id == 0 # just in case

    @cursize, @curfiles = Rails.cache.fetch(
        "disk_usage-u=#{user_id}-dp=#{data_provider_id}",
        :expires_in => CACHED_USAGE_EXPIRATION
      ) do
      req = Userfile
              .where(:user_id          => user_id)
              .where(:data_provider_id => data_provider_id)
      [ req.sum(:size), req.sum(:num_files) ]
    end

    what_is_exceeded = nil

    if @cursize  > self.max_bytes
      what_is_exceeded = :bytes
    end

    if @curfiles > self.max_files
      what_is_exceeded &&= :bytes_and_files
      what_is_exceeded ||= :files
    end

    return what_is_exceeded # one of nil, :bytes, :files, or :bytes_and_files
  end

  # Same as the 'exceeded?' but raises a CbrainDiskQuotaExceeded
  # exception if the quota is exceeded. Returns nil if everything is ok.
  def exceeded!(user_id = self.user_id)
    return nil if user_id == 0 # just in case
    return nil if ! self.exceeded?(user_id)
    raise CbrainDiskQuotaExceeded.new(user_id, self.data_provider_id)
  end

end
