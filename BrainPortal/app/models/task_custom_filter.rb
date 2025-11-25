
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

#Subclass of CustomFilter representing custom filters for the CbrainTask resource
#(which are controlled by the tasks contoller).
#
#=Parameters filtered:
#[*type*] The CbrainTask subclass to filter.
#[*description*] The CbrainTask description to filter.
#[*user_id*] The user_id of the CbrainTask owner to filter against.
#[*bourreau_id*] The bourreau_id of the bourreau to filter against.
class TaskCustomFilter < CustomFilter

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ########################################
  # Task Custom Attributes For Filtering #
  ########################################

  # This structure must match the argument syntax of
  # the permit() method of ActionController::Parameters
  WHITELIST_TASKS_FILTERING_PARAMS =
    [
      :description_term,
      :description_type,
      :wd_status,
      :archiving_status,
      {
        :user_ids     => [],
        :group_ids    => [],
        :bourreau_ids => [],
        :types        => [],
        :status       => [],
      }
    ]
  self.data_setter_and_getter(WHITELIST_TASKS_FILTERING_PARAMS)
  WHITELIST_FILTERING_PARAMS = merge_whitelist_filtering_params(WHITELIST_TASKS_FILTERING_PARAMS) # merge from superclasses too



  ######################################
  # Validation of Filtering Attributes #
  ######################################

  validate :valid_data_user_ids
  validate :valid_data_group_ids
  validate :valid_data_bourreau_ids
  validate :valid_data_types
  validate :valid_data_description
  validate :valid_data_wd_status
  validate :valid_data_status
  validate :valid_data_archiving_status

  def valid_data_user_ids #:nodoc:
    my_ids = cleaned_array_for_attribute(:user_ids)
    return true if my_ids.empty?
    return true if (my_ids.map(&:to_i) - self.user.available_users.pluck(:id)).empty?
    errors.add(:data_user_ids, 'are not all accessible users')
    false
  end

  def valid_data_group_ids #:nodoc:
    my_ids = cleaned_array_for_attribute(:group_ids)
    return true if my_ids.blank?
    return true if (my_ids.map(&:to_i) - self.user.viewable_group_ids).empty?
    errors.add(:data_group_ids, 'have groups that are not accessible')
    false
  end

  def valid_data_bourreau_ids #:nodoc:
    my_ids = cleaned_array_for_attribute(:bourreau_ids)
    return true if my_ids.empty?
    return true if (my_ids.map(&:to_i) - Bourreau.find_all_accessible_by_user(self.user).pluck(:id)).empty?
    errors.add(:data_bourreau_ids, 'are not all accessible bourreaux')
    return false
  end

  def valid_data_types #:nodoc:
    self.data_types = cleaned_array_for_attribute(:types)
    return true if self.data_types.empty?
    valid_types = CbrainTask.sti_descendant_names
    return true if ( self.data_types - valid_types ).empty?
    errors.add(:data_types, 'contains invalid file types')
    return false
  end

  def valid_data_description #:nodoc:
    if self.data_description_type.present? && !["match", "contain", "begin", "end"].include?(self.data_description_type)
      errors.add(:data_description_type, 'is not a valid description matcher')
      return false
    end
    if self.data_description_type.present?  && !self.data_description_term.present? ||
       !self.data_description_type.present? && self.data_description_term.present?
      errors.add(:data_description_type, 'both description fields should be set if you want to filter by description')
      return false
    end
    true
  end

  def valid_data_wd_status #:nodoc:
    return true if self.data_wd_status.blank?
    return true if [ 'shared', 'not_shared', 'exists', 'none' ].include? self.data_wd_status
    errors.add(:data_wd_status, 'is not a valid work directory status')
  end

  def valid_data_status #:nodoc:
    self.data_status = cleaned_array_for_attribute(:status)
    return true if self.data_status.empty?
    return true if ( self.data_status -  (CbrainTask::ALL_STATUS - ["Preset", "SitePreset", "Duplicated"])).empty?
    errors.add(:data_data_status, 'some task status are invalid')
    return false
  end

  def valid_data_archiving_status #:nodoc:
    return true if self.data_archiving_status.blank?
    return true if ["none", "cluster", "file"].include? self.data_archiving_status
    errors.add(:data_archiving_status, 'is not a valid archiving status')
    return false
  end



  ############################
  # Filtering Scope Builders #
  ############################

  # Returns table name for SQL filtering.
  # Used during datetime filtering implemented
  # in superclass CustomFilter
  def target_filtered_table
    "cbrain_tasks"
  end

  # See CustomFilter
  def filter_scope(scope)
    scope = super(scope)
    scope = scope_types(scope)        if self.data_types.present?
    scope = scope_description(scope)  if self.data_description_type.present? && self.data_description_term.present?
    scope = scope_user_ids(scope)     if self.data_user_ids.present?
    scope = scope_group_ids(scope)    if self.data_group_ids.present?
    scope = scope_bourreau_ids(scope) if self.data_bourreau_ids.present?
    scope = scope_status(scope)       if self.data_status.present?
    scope = scope_archive(scope)      if self.data_archiving_status.present?
    scope = scope_wd_status(scope)    if self.data_wd_status.present?
    scope
  end

  private

  # Returns +scope+ modified to filter the CbrainTask entry's type.
  def scope_types(scope)
    filter_by_attribute(scope, :type, self.data_types)
  end

  # Returns +scope+ modified to filter the CbrainTask entry's description.
  def scope_description(scope)
    query = 'cbrain_tasks.description'
    term = self.data_description_term
    term = "do-not-match-everything-#{rand(1000000)}" if term =~ /\A[\%\_\s]+\z/ # don't try matching all
    if self.data_description_type == 'match'
      query += ' = ?'
    else
      query += ' LIKE ?'
    end

    if self.data_description_type == 'contain' || self.data_description_type == 'begin'
      term += '%'
    end

    if self.data_description_type == 'contain' || self.data_description_type == 'end'
      term = '%' + term
    end

    scope.where(["#{query}", term])
  end

  # Returns +scope+ modified to filter the CbrainTask entry's owner.
  def scope_user_ids(scope)
    filter_by_attribute(scope, :user_id, self.data_user_ids)
  end

  # Return +scope+ modified to filter the Userfile entry's group ownership.
  def scope_group_ids(scope)
    filter_by_attribute(scope, :group_id, self.data_group_ids)
  end

  # Return +scope+ modified to filter the CbrainTask entry's bourreau.
  def scope_bourreau_ids(scope)
    filter_by_attribute(scope, :bourreau_id, self.data_bourreau_ids)
  end

  # Returns +scope+ modified to filter the CbrainTask entry's status.
  def scope_status(scope)
    filter_by_attribute(scope, :status, self.data_status)
  end

  # Returns +scope+ modified to filter the CbrainTask entry's archive.
  def scope_archive(scope)
    keyword = self.data_archiving_status || ""
    return scope.not_archived        if keyword == "none"
    return scope.archived_on_cluster if keyword == "cluster"
    return scope.archived_as_file    if keyword == "file"
    return scope # anything else, no operation.
  end

  # Returns +scope+ modified to filter the CbrainTask entry's work directory.
  def scope_wd_status(scope)
    keyword = self.data_wd_status || ""
    return scope.shared_wd      if keyword == 'shared'
    return scope.not_shared_wd  if keyword == 'not_shared'
    return scope.wd_present     if keyword == 'exists'
    return scope.wd_not_present if keyword == 'none'
    scope
  end

end
