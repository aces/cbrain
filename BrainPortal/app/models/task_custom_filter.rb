
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
#[*created_date_type*] The type of filtering done on the creation date (+before+, +on+ or +after+).
#[*created_date_term*] The date to filter against.
#[*user_id*] The user_id of the CbrainTask owner to filter against.
#[*bourreau_id*] The bourreau_id of the bourreau to filter against.
class TaskCustomFilter < CustomFilter

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # See CustomFilter
  def filter_scope(scope)
    scope = scope_type(scope)         unless self.data["type"].blank?
    scope = scope_description(scope)  unless self.data["description_type"].blank? || self.data["description_term"].blank?
    scope = scope_user(scope)         unless self.data["user_id"].blank?
    scope = scope_bourreau(scope)     unless self.data["bourreau_id"].blank?
    scope = scope_date(scope)         unless self.data["date_attribute"].blank?
    scope = scope_status(scope)       unless self.data["status"].blank?
    scope = scope_archive(scope)      unless self.data["archiving_status"].blank?
    scope = scope_wd_status(scope)    unless self.data["wd_status"].blank?
    scope
  end

  # Returns table name for SQL filtering
  def target_filtered_table
    "cbrain_tasks"
  end

  # Convenience method returning only the created_date_term in the data hash.
  def created_date_term
    self.data["created_date_term"]
  end

  # Virtual attribute for assigning the data_term to the data hash.
  def created_date_term=(date)
    self.data["created_date_term"] = "#{date["created_date_term(1i)"]}-#{date["created_date_term(2i)"]}-#{date["created_date_term(3i)"]}"
  end

  private

  # Returns +scope+ modified to filter the CbrainTask entry's type.
  def scope_type(scope)
    return scope if self.data["type"].is_a?(Array) && self.data["type"].all? { |v| v.blank? }
    scope.scoped(:conditions  => {:type  =>  self.data["type"]})
  end

  # Returns +scope+ modified to filter the CbrainTask entry's description.
  def scope_description(scope)
    query = 'cbrain_tasks.description'
    term = self.data["description_term"]
    if self.data["description_type"] == 'match'
      query += ' = ?'
    else
      query += ' LIKE ?'
    end

    if self.data["description_type"] == 'contain' || self.data["description_type"] == 'begin'
      term += '%'
    end

    if self.data["description_type"] == 'contain' || self.data["description_type"] == 'end'
      term = '%' + term
    end

    scope.scoped(:conditions  => ["#{query}", term])
  end

  # Returns +scope+ modified to filter the CbrainTask entry's owner.
  def scope_user(scope)
    scope.scoped(:conditions  => ["cbrain_tasks.user_id = ?", self.data["user_id"]])
  end

  # Return +scope+ modified to filter the CbrainTask entry's bourreau.
  def scope_bourreau(scope)
    scope.scoped(:conditions  => ["cbrain_tasks.bourreau_id = ?", self.data["bourreau_id"]])
  end

  # Returns +scope+ modified to filter the CbrainTask entry's status.
  def scope_status(scope)
    return scope if self.data["status"].is_a?(Array) && self.data["status"].all? { |v| v.blank? }
    scope.scoped(:conditions => {:status => self.data["status"]})
  end

  # Returns +scope+ modified to filter the CbrainTask entry's archive.
  def scope_archive(scope)
    keyword = self.data["archiving_status"] || ""
    case keyword
    when "none"
      return scope.not_archived
    when "cluster"
      return scope.archived_on_cluster
    when "file"
      return scope.archived_as_file
    end
    return scope # anything else, no operation.
  end

  # Returns +scope+ modified to filter the CbrainTask entry's work directory.
  def scope_wd_status(scope)
    keyword = self.data["wd_status"] || ""
    return scope.shared_wd      if keyword == 'shared'
    return scope.not_shared_wd  if keyword == 'not_shared'
    return scope.wd_present     if keyword == 'exists'
    return scope.wd_not_present if keyword == 'none'
    scope
  end

end
