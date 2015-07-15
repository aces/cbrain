
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

# Consistency checking API for data providers
module ConsistencyChecks

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Report any internal inconsistencies or issues inside the provider.
  # Inconsistencies are expected to be file-based (a registered
  # userfile no longer exists, for example), but the decision of
  # what constitutes an inconsistency is left to the provider subclass.
  # Returns an array of inconsistencies, which are hashes containing:
  #  [:id]       Identifier for the issue.
  #  [:message]  Nature of the issue
  #  [:severity] Severity of the issue.
  #              One of: :trivial, :minor, :major or :critical
  #  [:action]   Action that would be taken for repair
  #              (repair_action_<action> methods). If empty or not present,
  #              the issue cannot be repaired automatically.
  # Other attributes would typically be used by provider_repair to try and
  # repair the inconsistency if possible.
  #
  # NOTE Issue identifiers (:id) are only valid as long as the report is not
  # regenerated.
  #
  # FIXME this functionality should probably go in a separate module...
  # Since producing an inconsistency report is quite taxing, provider_report
  # caches the report, unless you specify +force_reload+.
  def provider_report(force_reload = nil)
    cb_error "Error: provider #{self.name} is offline." unless self.online?

    Rails.cache.delete(report_cache_key) if force_reload
    Rails.cache.fetch(report_cache_key) do
      impl_provider_report.each_with_index.map do |issue,ix|
        issue[:id] = ix unless issue.has_key?(:id)
        issue
      end
    end
  end

  # Try to automatically repair an inconsistency (+issue+) inside the provider
  # found by provider_report using impl_provider_repair. Throws an exception
  # if the repair cannot be performed, and just returns nil otherwise.
  def provider_repair(issue)
    cb_error "Error: provider #{self.name} is offline." unless self.online?

    impl_provider_repair(issue)

    # FIXME potential race condition
    issues = Rails.cache.read(report_cache_key)
    issues.delete_if { |i| i[:id] == issue[:id] }
    Rails.cache.write(report_cache_key, issues)
  end

  protected

  # Provider subclass consistency report implementation.
  # Override this method in a subclass to provide consistency reporting for
  # a data provider type.
  # By default, no issues are reported.
  def impl_provider_report
    []
  end

  # Provider subclass automatic issue reparation implementation.
  # Override this method in a subclass to customize automatic issue fixing.
  # By default, uses the issue's :action attribute (action_repair).
  def impl_provider_repair(issue)
    ConsistencyChecks.action_repair(self, issue)
  end

  # Returns the Rails cache key used to cache the results of provider_report.
  def report_cache_key
    "#{self.class.name}##{self.id}/consistency_report"
  end

  # Attempts to repair an +issue+ by taking the :action specified in the +issue+
  # and calling one of the repair_<action> methods. The source data provider is
  # supplied in the +provider+ parameter.
  def self.action_repair(provider, issue)
    repair_method = "repair_action_#{issue[:action].to_s}" if issue[:action]

    if self.respond_to?(repair_method, true)
      self.send(repair_method, provider, issue)
    else
      raise "No automatic repair possible."
    end
  end

  # Destroy an invalid userfile causing consistency issues. (repair action :destroy)
  # Requires the issue keys:
  #  [:userfile_id] ID of the userfile to destroy
  def self.repair_action_destroy(provider, issue)
    raise "No userfile to destroy." unless issue[:userfile_id]

    Userfile.find_by_id(issue[:userfile_id]).destroy
  end

  # Register a new userfile to solve consistency issues. (repair action :register)
  # Requires the issue keys:
  #  [:file_name] Name of the file to register
  #  [:user_id]   ID of the user to register the file to
  #  [:group_id]  ID of the group to register the file to.
  #               Defaults to the user's personal group if absent.
  def self.repair_action_register(provider, issue)
    raise "No file name to register."        unless issue[:file_name]
    raise "No user to register the file as." unless issue[:user_id]

    user = User.find_by_id(issue[:user_id])
    type = Userfile.suggested_file_type(issue[:file_name])
    raise "Unable to automatically detect the file's type for registration." unless type

    type.new(
      :name             => issue[:file_name],
      :user_id          => user.id,
      :group_id         => user.own_group.id,
      :data_provider_id => provider.id
    ).save!
  end

end
