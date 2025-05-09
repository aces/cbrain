
#
# CBRAIN Project
#
# Copyright (C) 2008-2025
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

# Model representing CPU quotas.
#
# Three attributes control the CPU limit of a user:
# user_id, bourreau_id, group_id. Quota records can
# have any of them set to 0 to mean "any". When
# checking for exceeded quotas, the records are
# fetched and checked  in this order of priority,
# if they exist:
#
#   # Priority |  Attributes present (non zero):
#   #          |  user_id  bourreau_id  group_id
#   # ---------|---------  -----------  --------
#   #    1     | user_id,  bourreau_id,    0
#   #    2     | user_id,       0,         0
#   #    3     |    0,     bourreau_id, group_id
#   #    4     |    0,     bourreau_id,    0
#   #    5     |    0,          0,      group_id
#
# The group_id is a way to specify a set of users instead
# of creating a bunch of separate quota object for all these
# users. Projects themselves do not have quotas, only users do.
#
# The three main attributes for CPU limits are
# :max_cpu_past_week, max_cpu_past_month and max_cpu_ever,
# which put limits to the sum(value) for particular records
# in the ResourceUsage table.
#
# Quotas are enforced by calls to the class method
# CpuQuota.exceeded?(user_id, remote_resource_id) in the
# CbrainTask classes and subclasses.
class CpuQuota < Quota

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :max_cpu_past_week
  validates_presence_of :max_cpu_past_month
  validates_presence_of :max_cpu_ever
  validate              :limits_are_reasonable
  validate              :user_exec_group_are_reasonable
  before_save           :nulllify_disk_quota_atts
  before_save           :zero_nil_relations

  belongs_to :user,            :optional => true # the value can be 0 but not nil
  belongs_to :group,           :optional => true
  belongs_to :remote_resource, :optional => true

  validates_uniqueness_of :user_id,            :scope => [ :remote_resource_id, :group_id ]
  validates_uniqueness_of :remote_resource_id, :scope => [ :user_id,            :group_id ]
  validates_uniqueness_of :group_id,           :scope => [ :remote_resource_id, :user_id  ]

  CACHED_USAGE_EXPIRATION = 10.minute # fetching usage is costly, we cache it

  # In seconds; values are filled when performing a check
  attr_reader :cpu_past_week
  attr_reader :cpu_past_month
  attr_reader :cpu_ever

  def is_for_user? #:nodoc:
    self.user_id != 0
  end

  def is_for_resource? #:nodoc:
    self.remote_resource_id != 0
  end

  def is_for_group? #:nodoc:
    self.group_id != 0
  end

  def none_allowed? #:nodoc:
    self.max_cpu_ever <= 0
  end

  # This is the main entry point in verifying quotas. We always require
  # both a user_id and a bourreau_id (aka remote_resource_id). This
  # method will try to find quota records that apply to the pair. There
  # are five types of records, and they will be checked in a specific
  # order of priority. As soon as a record of a type is found, the resuling
  # quota check for that record is the result returned.
  #
  # The types are identified by whether or not the user_id, group_id or
  # remote_resource_id is 0 in the record. A zero means 'any of them'
  # (e.g. user_id set to 0 means this quota applies to any/all users).
  #
  # The five type are, in order of priority (higher priority first):
  #
  #   # UserID  BourreauID GroupID Meaning
  #   # ------- ---------- ------- ------------------
  #   # yes     yes        0       Quota for a specific user on a specific bourreau
  #   # yes     0          0       Quota for a specific user on any bourreau
  #   # 0       yes        yes     Quota for any user in a group, on a specific bourreau
  #   # 0       yes        0       Quota for any user on a specific bourreau
  #   # 0       0          yes     Quota for any user in a group, any bourreau
  #
  # The remaining 3 combinations ([U, B, G], [U, 0, G] and [0,0 0]) are forbidden by
  # by DiskQuota validation rules.
  def self.exceeded?(user_id, remote_resource_id)

    # Checks quotas when the user is explicitly mentioned
    u_quota   = self.where(:user_id => user_id, :remote_resource_id => remote_resource_id).first
    u_quota ||= self.where(:user_id => user_id, :remote_resource_id => 0).first
    exceeded = u_quota.exceeded?(user_id, remote_resource_id) if u_quota
    return exceeded if u_quota

    # List of groups the user belongs to. No restrictions as to the types here.
    user_group_ids = User.joins(:groups).where('users.id' => user_id).pluck('groups.id')

    # Check quotas for bourreau+groups; first failure is returned
    bg_quotas = self.where(:remote_resource_id => remote_resource_id,
                           :group_id           => user_group_ids).to_a
    exceeded = bg_quotas.detect { |quota| quota.exceeded?(user_id, remote_resource_id) }
    return exceeded if bg_quotas.present?

    # Check quota for just the bourreau, any user
    b_quota = self.where(:user_id => 0, :remote_resource_id => remote_resource_id).first
    exceeded = b_quota.exceeded?(user_id, remote_resource_id) if b_quota
    return exceeded if b_quota

    # Check for quotas for the user's groups, applying to any bourreau and any user
    g_quotas = self.where(:remote_resource_id => 0,
                          :user_id            => 0,
                          :group_id           => user_group_ids).to_a
    exceeded = g_quotas.detect { |quota| quota.exceeded?(user_id, remote_resource_id) }
    return exceeded if g_quotas.present?

    return nil
  end

  # Same as the 'exceeded?' but raises an  exception if the quota is exceeded.
  # Possible exceptions are WeeklyCpuQuotaExceeded, MonthlyCpuQuotaExceeded and
  # CbrainCpuQuotaExceeded.
  # Returns nil if everything is ok.
  def self.exceeded!(user_id, remote_resource_id)
    what = self.exceeded?(user_id, remote_resource_id)
    raise  WeeklyCpuQuotaExceeded.new(user_id, remote_resource_id) if what == :week
    raise MonthlyCpuQuotaExceeded.new(user_id, remote_resource_id) if what == :month
    raise  CbrainCpuQuotaExceeded.new(user_id, remote_resource_id) if what
    nil
  end

  # Returns true if currently, the user specified by +user_id+
  # has used more CPU than configured in the limits of this
  # quota object. Since a quota object can contain '0' for the user attribute
  # (meaning it's a default for all users), a user_id must always be given
  # explicitely in argument.
  def exceeded?(user_id, remote_resource_id)

    # Some sanity checks
    cb_error "CpuQuota 'exceeded?' method requires both user_id and remote_resource_id" if
      user_id.blank? || remote_resource_id.blank?
    return nil if user_id == 0 # just in case; should never happen
    return nil if remote_resource_id == 0 # also should never happen

    # These checks involve the (wrong) case where the arguments given
    # don't apply at all to the current quota object. TODO: raise an exception?
    return nil if self.user_id            > 0 && user_id            != self.user_id
    return nil if self.remote_resource_id > 0 && remote_resource_id != self.remote_resource_id
    return nil if self.group_id           > 0 &&
       (! Group.where('groups.id' => self.group_id).joins(:users).where('users.id' => user_id).exists?)

    # This is the costly check; so we cache the results.
    # The values cached are for the current pair (user_id, remote_resource_id)
    @cpu_past_week, @cpu_past_month, @cpu_ever =
      Rails.cache.fetch(
        "cpu_usage-u=#{user_id}-rr=#{remote_resource_id}",
        :expires_in => CACHED_USAGE_EXPIRATION
      ) do
      req = CputimeResourceUsageForCbrainTask
              .where(:user_id            => user_id)
              .where(:remote_resource_id => remote_resource_id)
      req_week  = req.where('created_at > ?',1.week.ago)
      req_month = req.where('created_at > ?',1.month.ago)
      [ req_week.sum(:value), req_month.sum(:value), req.sum(:value) ]
    end

    return :week  if @cpu_past_week  >= self.max_cpu_past_week
    return :month if @cpu_past_month >= self.max_cpu_past_month
    return :ever  if @cpu_ever       >= self.max_cpu_ever

    nil
  end

  # Same as the 'exceeded?' but raises a CbrainCpuQuotaExceeded
  # exception if the quota is exceeded. Returns nil if everything is ok.
  def exceeded!(user_id, remote_resource_id)
    what = self.exceeded?(user_id, remote_resource_id)
    raise  WeeklyCpuQuotaExceeded.new(user_id, remote_resource_id) if what == :week
    raise MonthlyCpuQuotaExceeded.new(user_id, remote_resource_id) if what == :month
    raise  CbrainCpuQuotaExceeded.new(user_id, remote_resource_id) if what
    nil
  end

  #####################################################
  # Validations callbacks
  #####################################################

  # Checks that limits have proper values.
  # All values must be 0 or greater than 0.
  def limits_are_reasonable
    # Already checked by other validate_presence callbacks
    return false if self.max_cpu_past_week.blank? ||
                    self.max_cpu_past_month.blank? ||
                    self.max_cpu_ever.blank?

    # Log errors for bad values
    self.errors.add(:max_cpu_past_week,  "must be 0 or > 0") if self.max_cpu_past_week  < 0
    self.errors.add(:max_cpu_past_month, "must be 0 or > 0") if self.max_cpu_past_month < 0
    self.errors.add(:max_cpu_ever,       "must be 0 or > 0") if self.max_cpu_ever       < 0

    # log inconsistencies between the limits
    self.errors.add(:max_cpu_past_month, "cannot be less than the limit for the week")  if
      self.max_cpu_past_month <  self.max_cpu_past_week
    self.errors.add(:max_cpu_ever,       "cannot be less than the limit for the month") if
      self.max_cpu_ever       <  self.max_cpu_past_month

    return ! self.errors.any?
  end


  # This validates that the combinations for user_id, remote_resource_id
  # and group_id are valid. See also the class method DiskQuota.exceeded?()
  #
  #   # Allowed:
  #   # U X G
  #   # -----
  #   # y - - case 1
  #   # - y - case 2
  #   # - - y case 3
  #   # y y - case 4
  #   # - y y case 5
  def user_exec_group_are_reasonable #:nodoc:
    uid  = self.user_id            || 0
    rrid = self.remote_resource_id || 0
    gid  = self.group_id           || 0
    return true if uid > 0 &&  gid == 0  # case 1 and 4
    return true if gid > 0 &&  uid == 0  # case 3 and 5
    return true if rrid > 0 && uid == 0 && gid == 0 # case 2
    self.errors.add(:user_id,  'cannot be configured with a group too') if uid > 0
    self.errors.add(:group_id, 'cannot be configured with a user too')  if gid > 0
    self.errors.add(:base, 'need at least one of user, group, or execution server') if self.errors.empty?
    false
  end

  # This attribute is only for DiskQuota; since we using STI,
  # we keep it clean by zapping it.
  def nulllify_disk_quota_atts
    self.data_provider_id = nil
    true
  end

  # Replaces nil with zeros in our three main ID attributes
  def zero_nil_relations
    self.user_id            ||= 0
    self.remote_resource_id ||= 0
    self.group_id           ||= 0
    if self.user_id == 0 && self.remote_resource_id == 0 && self.group_id == 0
      self.errors.add(:base, 'One of user, remote_resource, or group must be present')
      throw :abort
    end
    true
  end

end
