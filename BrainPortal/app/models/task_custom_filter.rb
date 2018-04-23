
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

  DATA_PARAMS = merge_data_params(
    [
      :data_provider_id,
      :data_provider,
      :description_term,
      :description_type,
      :bourreau_id,
      :bourreau,
      :wd_status,
      :status,
    ])

  # Define getter and setter for each keys in data attribute
  DATA_PARAMS.map{|x| x.is_a?(Hash) ? x.keys : x}.flatten.each do |param|
    # Define getter for all keys in data attribute
    define_method("data_#{param}") do
      self.data[param]
    end

    # Define setter for all keys in data attribute
    define_method("data_#{param}=") do |val|
      self.data[param] = val
    end
  end

  # See CustomFilter
  def filter_scope(scope)
    scope = scope_type(scope)         if self.data_type.present?
    scope = scope_description(scope)  if self.data_description_type.present? && self.data_description_term.present?
    scope = scope_user(scope)         if self.data_user_id.present?
    scope = scope_bourreau(scope)     if self.data_bourreau_id.present?
    scope = scope_date(scope)         if self.data_date_attribute.present?
    scope = scope_status(scope)       if self.data_status.present?
    scope = scope_archive(scope)      if self.data_archiving_status.present?
    scope = scope_wd_status(scope)    if self.data_wd_status.present?
    scope
  end

  # Returns table name for SQL filtering
  def target_filtered_table
    "cbrain_tasks"
  end

  private

  # Returns +scope+ modified to filter the CbrainTask entry's type.
  def scope_type(scope)
    return scope if self.data_type.is_a?(Array) && self.data_type.all? { |v| v.blank? }
    scope.where(:type => self.data_type)
  end

  # Returns +scope+ modified to filter the CbrainTask entry's description.
  def scope_description(scope)
    query = 'cbrain_tasks.description'
    term = self.data_description_term
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
  def scope_user(scope)
    scope.where(["cbrain_tasks.user_id = ?", self.data_user_id])
  end

  # Return +scope+ modified to filter the CbrainTask entry's bourreau.
  def scope_bourreau(scope)
    scope.where(["cbrain_tasks.bourreau_id = ?", self.data_bourreau_id])
  end

  # Returns +scope+ modified to filter the CbrainTask entry's status.
  def scope_status(scope)
    return scope if self.data_status.is_a?(Array) && self.data_status.all? { |v| v.blank? }
    scope.where(:status => self.data_status)
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
