
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
# [*size_type*] The type of filtering done on the file size (>, < or =).
# [*size_term*] The file size to filter against.
# [*group_id*] The id of the group to filter on.
# [*tags*] A serialized hash of tags to filter on.

class UserfileCustomFilter < CustomFilter

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ###############################
  # Validation of Custom Filter #
  ###############################

  validate :valid_filename
  validate :valid_size
  validate :valid_data_group_id
  validate :valid_data_tag_ids
  validate :valid_data_data_provider_id
  validate :valid_data_sync_status

  def valid_filename #:nodocs:
    if !["", "match", "contain", "begin", "end"].include? self.data_file_name_type
      errors.add(:file_name_type, 'is not a valid file name matcher')
      return false
    end
    if self.data_file_name_type.blank? && !self.data_file_name_term.blank?
      errors.add(:file_name_type, 'both filename fields should be set if you want to filter by filename')
      return false
    end
    true
  end

  def valid_size #:nodocs:
    return true if self.data_size_type.blank? && self.data_size_term.blank?
    if self.data_size_type.blank? && self.data_size_term.present?
      errors.add(:data_size, 'both size fields should be set if you want to filter by size')
      return false
    end
    if !["1","2"].include? self.data_size_type
      errors.add(:data_size_term, 'is not a valid operator for size comparaison')
      return false
    end
    if self.data_size_term.blank?
      errors.add(:data_size_term, 'should be set')
      return false
    end
    if self.data_size_term !~ /^\d+$/
      errors.add(:data_size_term, "should be an integer")
      return false
    end
    return true
  end

  def valid_data_group_id #:nodocs:
    return true if self.data_group_id.blank?
    return true if self.user.available_groups.pluck(:id).include? self.data_group_id.to_i
    errors.add(:data_group_id, 'is not an accessible group')
    false
  end

  def valid_data_tag_ids #:nodocs:
    self.data_tag_ids = Array(self.data_tag_ids).reject { |item| item.blank? }
    return true if self.data_tag_ids.empty?
    return true if ( self.data_tag_ids - self.user.available_tags.pluck(:id).map(&:to_s) ).empty?
    errors.add(:data_tag_ids, 'some tags are not accessible')
    return false
  end

  def valid_data_data_provider_id #:nodocs:
    return true if self.data_data_provider_id.blank?
    return true if DataProvider.find_all_accessible_by_user(self.user).pluck(:id).include? self.data_group_id.to_i
    errors.add(:data_data_provider_id, 'is not an accessible data provider')
    false
  end

  def valid_data_sync_status #:nodocs:
    self.data_sync_status = Array(self.data_sync_status).reject { |item| item.blank? }
    return true if self.data_sync_status.empty?
    return true if
      ( self.data_sync_status - ["InSync","ProvNewer","CacheNewer","Corrupted","ToCache","ToProvider"] ).empty?
    errors.add(:data_sync_status, 'is not a valid sync status')
    return false
  end

  #####################################
  # Define getter and setter for data #
  #####################################


  DATA_PARAMS = merge_data_params(
    [
      :size_type,
      :size_term,
      :file_name_type,
      :group_id,
      :group,
      :data_provider_id,
      :file_name_term,
      :description_type,
      :parent_name_like,
      :child_name_like,
      :archiving_status,
      :sync_status,
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
    scope = scope_name(scope)        if self.data_file_name_type.present? && self.data_file_name_term.present?
    scope = scope_parent_name(scope) if self.data_parent_name_like.present?
    scope = scope_child_name(scope)  if self.data_child_name_like.present?
    scope = scope_date(scope)        if self.data_date_attribute.present?
    scope = scope_size(scope)        if self.data_size_type.present?      && self.data_size_term.present?
    scope = scope_user(scope)        if self.data_user_id.present?
    scope = scope_group(scope)       if self.data_group_id.present?
    scope = scope_dp(scope)          if self.data_data_provider_id.present?
    scope = scope_type(scope)        if self.data_type.present?
    scope = scope_archive(scope)     if self.data_archiving_status.present?
    scope = scope_syncstatus(scope)  if self.data_sync_status.present?
    scope = scope_tags(scope)        if self.data_tag_ids.present?
    scope
  end

  # Return table name for SQL filtering
  def target_filtered_table
    "userfiles"
  end



  private

  # Return +scope+ modified to filter the Userfile entry's name.
  def scope_name(scope)
    query = 'userfiles.name'
    term = self.data_file_name_term
    if self.data_file_name_type == 'match'
      query += ' = ?'
    else
      query += ' LIKE ?'
    end

    if self.data_file_name_type == 'contain' || self.data_file_name_type == 'begin'
      term += '%'
    end

    if self.data_file_name_type == 'contain' || self.data_file_name_type == 'end'
      term = '%' + term
    end

    scope.where( ["#{query}", term] )
  end

  # Return +scope+ modified to filter the Userfile with parent name.
  def scope_parent_name(scope)
    scope.parent_name_like(self.data_parent_name_like)
  end

  # Return +scope+ modified to filter the Userfile with child name.
  def scope_child_name(scope)
    scope.child_name_like(self.data_child_name_like)
  end

  # Return +scope+ modified to filter the Userfile entry's size.
  def scope_size(scope)
    scope.where( ["userfiles.size #{inequality_type(self.data_size_type)} ?", (self.data_size_term.to_f * 1000)])
  end

  # Return +scope+ modified to filter the Userfile entry's owner.
  def scope_user(scope)
    scope.where( ["userfiles.user_id = ?", self.data_user_id])
  end

  # Return +scope+ modified to filter the Userfile entry's group ownership.
  def scope_group(scope)
    scope.where( ["userfiles.group_id = ?", self.data_group_id])
  end

  # Return +scope+ modified to filter the Userfile entry's data provider.
  def scope_dp(scope)
    scope.where( ["userfiles.data_provider_id = ?", self.data_data_provider_id])
  end

  # Return +scope+ modified to filter the Userfile entry's type.
  def scope_type(scope)
    scope.where( :type => self.data_type )
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
    keyword = self.data_archiving_status || ""
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
    scope.joins(:sync_status).where(:sync_status => {:status => self.data_sync_status})
  end

  # Return +scope+ modified to filter the Userfile entry's by tag_ids.
  def scope_tags(scope)
    scope.contain_tags((self.data_tag_ids).flatten.uniq)
  end

end
