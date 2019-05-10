
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

  #############################################
  # Userfiles Custom Attributes For Filtering #
  #############################################

  USERFILES_DATA_PARAMS =
    [
      :user_id,
      :group_id,
      :file_name_type,
      :file_name_term,
      :size_type,
      :size_term,
      :data_provider_id,
      :parent_name_like,
      :child_name_like,
      :archiving_status,
      {
        :type        => [],
        :sync_status => [],
        :tag_ids     => [],
      }
    ]
  self.data_setter_and_getter(USERFILES_DATA_PARAMS)

  DATA_PARAMS = merge_data_params(USERFILES_DATA_PARAMS) # merge from superclasses too



  ######################################
  # Validation of Filtering Attributes #
  ######################################

  validate :valid_data_user_id
  validate :valid_data_group_id
  validate :valid_data_type
  validate :valid_data_filename
  validate :valid_data_size
  validate :valid_data_tag_ids
  validate :valid_data_data_provider_id
  validate :valid_data_sync_status
  validate :valid_data_archiving_status

  def valid_data_type #:nodoc:
    self.data_type = Array(self.data_type).reject { |item| item.blank? }
    return true if self.data_type.empty?
    valid_type = Userfile.sti_descendant_names
    return true if ( self.data_type - valid_type ).empty?
    errors.add(:data_data_type, 'some file types are invalid')
    return false
  end

  def valid_data_user_id #:nodoc:
    return true if self.data_user_id.blank?
    return true if self.user.available_users.pluck(:id).include? self.data_user_id.to_i
    errors.add(:data_user_id, 'is not an accessible user')
    false
  end

  def valid_data_filename #:nodoc:
    if self.data_file_name_type.present? && !["match", "contain", "begin", "end"].include?(self.data_file_name_type)
      errors.add(:file_name_type, 'is not a valid file name matcher')
      return false
    end
    if self.data_file_name_type.present?  && !self.data_file_name_term.present? ||
       !self.data_file_name_type.present? && self.data_file_name_term.present?
      errors.add(:file_name_type, 'both filename fields should be set if you want to filter by filename')
      return false
    end
    true
  end

  def valid_data_size #:nodoc:
    return true if self.data_size_type.blank? && self.data_size_term.blank?
    if self.data_size_type.present?  && !self.data_size_term.present? ||
       !self.data_size_type.present? && self.data_size_term.present?
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

  def valid_data_group_id #:nodoc:
    return true if self.data_group_id.blank?
    return true if self.user.available_groups.pluck(:id).include? self.data_group_id.to_i
    errors.add(:data_group_id, 'is not an accessible group')
    false
  end

  def valid_data_tag_ids #:nodoc:
    self.data_tag_ids = Array(self.data_tag_ids).reject { |item| item.blank? }
    return true if self.data_tag_ids.empty?
    return true if ( self.data_tag_ids - self.user.available_tags.pluck(:id).map(&:to_s) ).empty?
    errors.add(:data_tag_ids, 'some tags are not accessible')
    return false
  end

  def valid_data_data_provider_id #:nodoc:
    return true if self.data_data_provider_id.blank?
    return true if DataProvider.find_all_accessible_by_user(self.user).pluck(:id).include? self.data_data_provider_id.to_i
    errors.add(:data_data_provider_id, 'is not an accessible data provider')
    false
  end

  def valid_data_sync_status #:nodoc:
    self.data_sync_status = Array(self.data_sync_status).reject { |item| item.blank? }
    return true if self.data_sync_status.empty?
    return true if
      ( self.data_sync_status - ["InSync","ProvNewer","CacheNewer","Corrupted","ToCache","ToProvider"] ).empty?
    errors.add(:data_sync_status, 'is not a valid sync status')
    return false
  end

  def valid_data_archiving_status #:nodoc:
    return true if self.data_archiving_status.blank?
    return true if ["archived", "none"].include? self.data_archiving_status
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
    "userfiles"
  end

  # See CustomFilter
  def filter_scope(scope)
    scope = super(scope)
    scope = scope_name(scope)        if self.data_file_name_type.present? && self.data_file_name_term.present?
    scope = scope_parent_name(scope) if self.data_parent_name_like.present?
    scope = scope_child_name(scope)  if self.data_child_name_like.present?
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
    Array(self.data_type).each do |klassname|
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
