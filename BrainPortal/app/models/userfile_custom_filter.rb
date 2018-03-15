
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

# Subclass of CustomFilter representing custom filters for the Userfile resource.
#
# =Parameters filtered:
# [*file_name_type*] The type of filtering done on the filename (+matches+, <tt>begins with</tt>, <tt>ends with</tt> or +contains+).
# [*file_name_term*] The string or substring to search for in the filename.
# [*created_date_type*] The type of filtering done on the creation date (+before+, +on+ or +after+).
# [*created_date_term*] The date to filter against.
# [*size_type*] The type of filtering done on the file size (>, < or =).
# [*size_term*] The file size to filter against.
# [*group_id*] The id of the group to filter on.
# [*tags*] A serialized hash of tags to filter on.

require 'pry'

class UserfileCustomFilter < CustomFilter

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # See CustomFilter
  def filter_scope(scope)
    scope = scope_name(scope)        unless self.data[:file_name_type].blank? || self.data[:file_name_term].blank?
    scope = scope_parent_name(scope) unless self.data[:parent_name_like].blank?
    scope = scope_child_name(scope)  unless self.data[:child_name_like].blank?
    scope = scope_date(scope)        unless self.data[:date_attribute].blank?
    scope = scope_size(scope)        unless self.data[:size_type].blank? || self.data[:size_term].blank?
    scope = scope_user(scope)        unless self.data[:user_id].blank?
    scope = scope_group(scope)       unless self.data[:group_id].blank?
    scope = scope_dp(scope)          unless self.data[:data_provider_id].blank?
    scope = scope_type(scope)        unless self.data[:type].blank?
    scope = scope_archive(scope)     unless self.data[:archiving_status].blank?
    scope = scope_syncstatus(scope)  unless self.data[:sync_status].blank?
    scope = scope_tags(scope)        unless self.data[:tag_ids].blank?
    scope
  end

  # Return table name for SQL filtering
  def target_filtered_table
    "userfiles"
  end

  # Virtual attribute for assigning tags to the data hash.
  def tag_ids=(ids)
    self.data[:tag_ids] = Tag.find(ids).collect{ |tag| "#{tag.id}"}
  end

  # Convenience method returning only the tags in the data hash.
  def tag_ids
    self.data[:tag_ids] || []
  end

  # Convenience method returning only the date_term in the data hash.
  def date_term
    self.data[:date_term]
  end

  # Virtual attribute for assigning the data_term to the data hash.
  def date_term=(date)
    self.data[:date_term] = "#{date["date_term(1i)"]}-#{date["date_term(2i)"]}-#{date["date_term(3i)"]}"
  end

  private

  # Return +scope+ modified to filter the Userfile entry's name.
  def scope_name(scope)
    query = 'userfiles.name'
    term = self.data[:file_name_term]
    if self.data[:file_name_type] == 'match'
      query += ' = ?'
    else
      query += ' LIKE ?'
    end

    if self.data[:file_name_type] == 'contain' || self.data[:file_name_type] == 'begin'
      term += '%'
    end

    if self.data[:file_name_type] == 'contain' || self.data[:file_name_type] == 'end'
      term = '%' + term
    end

    scope.where( ["#{query}", term] )
  end

  # Return +scope+ modified to filter the Userfile with parent name.
  def scope_parent_name(scope)
    scope.parent_name_like(self.data[:parent_name_like])
  end

  # Return +scope+ modified to filter the Userfile with child name.
  def scope_child_name(scope)
    scope.child_name_like(self.data[:child_name_like])
  end

  # Return +scope+ modified to filter the Userfile entry's size.
  def scope_size(scope)
    scope.where( ["userfiles.size #{inequality_type(self.data[:size_type])} ?", (self.data[:size_term].to_f * 1000)])
  end

  # Return +scope+ modified to filter the Userfile entry's owner.
  def scope_user(scope)
    scope.where( ["userfiles.user_id = ?", self.data[:user_id]])
  end

  # Return +scope+ modified to filter the Userfile entry's group ownership.
  def scope_group(scope)
    scope.where( ["userfiles.group_id = ?", self.data[:group_id]])
  end

  # Return +scope+ modified to filter the Userfile entry's data provider.
  def scope_dp(scope)
    scope.where( ["userfiles.data_provider_id = ?", self.data[:data_provider_id]])
  end

  # Return +scope+ modified to filter the Userfile entry's type.
  def scope_type(scope)
    scope.where( :type => self.data[:type] )
  end

  # Return +scope+ modified to filter the Userfile entry's type.
  # This scope filters by all subclasses of the chosen class type.
  # Not used by interface yet.
  def scope_type_tree(scope)
    flatlist = []
    Array(self.data[:type]).each do |klassname|
      subtypes = klassname.constantize.descendants.map(&:name)
      subtypes << klassname  # because descendants() does not include the class itself
      flatlist += subtypes
    end
    scope.where( :type => flatlist.uniq )
  end

  # Return +scope+ modified to filter the Userfile entry's by archived status.
  def scope_archive(scope)
    keyword = self.data[:archiving_status] || ""
    case keyword
    when "none"
      return scope.where( :archived => false )
    when "archived"
      return scope.where( :archived => true )
    end
    return scope # anything else, no operation
  end

  # Return +scope+ modified to filter the Userfile entry's sync_status.
  # note that the scope will return 1 entry by status/file combination.
  def scope_syncstatus(scope)
    scope.joins(:sync_status).where(:sync_status => {:status => self.data[:sync_status]})
  end

  # Return +scope+ modified to filter the Userfile entry's by tag_ids.
  def scope_tags(scope)
    scope.contain_tags((self.data[:tag_ids]).flatten.uniq)
  end

end
