
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

#This model represents a user defined filter. The class is not meant
#to be used directly, but instead to be subclassed for the particular
#resource to be filtered. The most critical aspect in the subclass
#is it's redifinition of the method filter_scope.
#
#=*IMPORTANT*: Naming conventions
#[*Controller*] The name of the subclass should be the camelcased name of
#               of the filtered resource as it appears in its controller. E.g.
#               UserfileCustomFilter filters on the UserfilesController,
#               TaskCustomFilter filters on the TasksController. Alternatively,
#               the method filtered_class_controller can be redifined to return the
#               the name of the controller being filtered on.
#[<b>Partial for new and edit actions</b>] This should saved in app/view/custom_filter/ and
#                                          should match the underscored version of the class
#                                          name. E.g. _userfile_custom_filter.html.erb for
#                                          UserfileCustomFilter.
#[<b>Type parameter</b>] A type paramter will be sent to the new and create actions of the
#                        CustomFilterController. This parameter should match the part of
#                        of the class name excluding "CustomFilter". E.g. for UserfileCustomFilter,
#                        the type parameter should be "userfile".
#
#=Attributes:
#[*name*] A string representing the name of the filter.
#[*data*] A hash containing the filter parameters.
#= Associations:
#*Belongs* *to*:
#* User
class CustomFilter < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # A Custom filter have a hash containing the filter parameters
  # The DATA_PARAMS array is used to withelist these params.
  DATA_PARAMS =
  [
    # Data available on all subclasses
    :date_attribute,
    :absolute_or_relative_to,
    :absolute_or_relative_from,
    :absolute_or_relative_to,
    :rel_date_from,
    :rel_date_to,
    :abs_from,
    :abs_to,
    :relative_from,
    :absolute_from,
    :relative_to,
    :absolute_to,
    :archiving_status,
    :user_id,
    :user,

    # all the array params need to be at the end
    # of the allowed keys
    {
      :type        => [],
      :status      => [],
      :sync_status => [],
      :tag_ids     => [],
    }
  ]

  include DateRangeRestriction

  serialize_as_indifferent_hash :data

  belongs_to :user

  validates_presence_of   :name
  validates_uniqueness_of :name, :scope  => [:user_id, :type]
  validates_format_of     :name, :with => /\A[\w\-\=\.\+\?\!\s]*\z/,
                                 :message  => 'only the following characters are valid: alphanumeric characters, spaces, _, -, =, +, ., ?, !'

  validate :valid_self_user

  validate :valid_data_type
  validate :valid_data_user_id
  validate :valid_data_archiving_status
  validate :valid_data_date

  validate :valid_filename,              if: -> { self.is_a?(UserfileCustomFilter)}
  validate :valid_size,                  if: -> { self.is_a?(UserfileCustomFilter)}
  validate :valid_data_group_id,         if: -> { self.is_a?(UserfileCustomFilter)}
  validate :valid_data_tag_ids,          if: -> { self.is_a?(UserfileCustomFilter)}
  validate :valid_data_data_provider_id, if: -> { self.is_a?(UserfileCustomFilter)}
  validate :valid_data_sync_status,      if: -> { self.is_a?(UserfileCustomFilter)}


  validate :valid_data_wd_status,        if: -> { self.is_a?(TaskCustomFilter)}
  validate :valid_data_bourreau_id,      if: -> { self.is_a?(TaskCustomFilter)}
  validate :valid_data_status,           if: -> { self.is_a?(TaskCustomFilter)}


  ###############################
  # Validation of Custom Filter #
  ###############################

  def valid_self_user #:nodocs:
    return true if self.user
    errors.add(:base, 'a custom filter should have a user')
    return false
  end

  def valid_filename #:nodocs:
    if !["", "match", "contain", "begin", "end"].include? self.data_file_name_type
      errors.add(:data_file_name_type, 'is not a valid file name matcher')
      return false
    end
    if self.data_file_name_type.blank? && !self.data_file_name_term.blank?
      errors.add(:data_file_name_type, 'both filename fields should be set if you want to filter by filename')
      return false
    end
    true
  end

  def valid_data_type #:nodocs:
    return true if self.data_type.blank?
    valid_type = self.is_a?(TaskCustomFilter) ? CbrainTask.sti_descendant_names : Userfile.sti_descendant_names
    return true if ( Array(self.data_type) - valid_type ).empty?
    errors.add(:data_data_type, 'some file type are invalid')
    return false
  end

  def valid_data_status #:nodocs:
    return true if self.data_status.blank?
    return true if ( Array(self.data_status) -  (CbrainTask::ALL_STATUS - ["Preset", "SitePreset", "Duplicated"])).empty?
    errors.add(:data_data_status, 'some task status are invalid')
    return false
  end

  def valid_size #:nodocs:
    return true if self.data_size_type.blank?
    if !["1","2"].include? self.data_size_type
      errors.add(:data_size_type, 'is not a valid operator for size comparaison')
      return false
    end
    if self.data_size_term.blank?
      errors.add(:data_size_term, 'should be set')
      return false
    end
    return true
  end

  def valid_data_user_id #:nodocs:
    return true if self.data_user_id.blank?
    return true if self.user.available_users.pluck(:id).include? self.data_user_id.to_i
    errors.add(:data_user_id, 'is not an accessible user')
    false
  end

  def valid_data_group_id #:nodocs:
    return true if self.data_group_id.blank?
    return true if self.user.available_groups.pluck(:id).include? self.data_group_id.to_i
    errors.add(:data_group_id, 'is not an accessible group')
    false
  end

  def valid_data_data_provider_id #:nodocs:
    return true if self.data_data_provider_id.blank?
    return true if DataProvider.find_all_accessible_by_user(self.user).pluck(:id).include? self.data_group_id.to_i
    errors.add(:data_data_provider_id, 'is not an accessible data provider')
    false
    end

  def valid_data_archiving_status #:nodocs:
    return true if self.data_archiving_status.blank?
    valid_status = self.is_a?(TaskCustomFilter) ? ["none", "cluster", "file"] : ["archived", "none"]
    return true if valid_status.include? self.data_archiving_status
    errors.add(:data_archiving_status, 'is not a valid archiving status')
    return false
  end

  def valid_data_sync_status #:nodocs:
    return true if self.data_sync_status.blank?
    return true if
      ( self.data_sync_status - ["InSync","ProvNewer","CacheNewer","Corrupted","ToCache","ToProvider"] ).empty?
    errors.add(:data_sync_status, 'is not a valid sync status')
    return false
  end

  def valid_data_tag_ids #:nodocs:
    return true if self.data_tag_ids.blank?
    return true if ( Array(self.data_tag_ids) - self.user.available_tags.pluck(:id).map(&:to_s) ).empty?
    errors.add(:data_tag_ids, 'some tags are not accessible')
    return false
  end

  def valid_data_bourreau_id #:nodocs:
    return true if self.data_bourreau_id.blank?
    Bourreau.find_all_accessible_by_user(self.user).pluck(:id).include? self.data_bourreau_id.to_i
    errors.add(:data_bourreau_id, 'is not an accessible bourreau')

  end

  def valid_data_wd_status #:nodocs:
    return true if self.data_wd_status.blank?
    return true if [ 'shared', 'not_shared', 'exists', 'none' ].include? self.data_wd_status
    errors.add(:data_wd_status, 'is not a valid work directory status')
  end

  # Do some validation on the date range filtering
  def valid_data_date #:nodocs:
    error_mess = check_filter_date(self.data["date_attribute"],  self.data["absolute_or_relative_from"], self.data["absolute_or_relative_to"],
                                   self.data["absolute_from"], self.data["absolute_to"], self.data["relative_from"], self.data["relative_to"])

    return true if error_mess == ""
    errors.add(:base, error_mess)
    return false
  end

  # Main method used for custom filtering. Should be redefined in subclasses to
  # modify +scope+ according to the filter parameters and return it.
  def filter_scope(scope)
    raise "Using filter_scope in CustomFilter base class. Should be used from a subclass."
  end

  # Returns the name of the controller of the resource being filtered.
  def filtered_class_controller
    @filtered_class_controller ||= self.class.to_s.sub(/CustomFilter\z/, "").tableize
  end


  # Return +scope+ modified to filter the CbrainTask entry's dates.
  def scope_date(scope)

    date_at               = self.data_date_attribute # assignation ...
    mode_is_absolute_from = self.data_absolute_or_relative_from == "absolute"
    mode_is_absolute_to   = self.data_absolute_or_relative_to   == "absolute"
    absolute_from         = self.data_absolute_from
    absolute_to           = self.data_absolute_to
    relative_from         = self.data_relative_from
    relative_to           = self.data_relative_to
    table_name            = self.target_filtered_table

    scope = add_time_condition_to_scope(scope,table_name,mode_is_absolute_from,mode_is_absolute_to,
                                     absolute_from, absolute_to, relative_from, relative_to,date_at );
  end

  # Wrapper for the data attribute. Ensures it's always initialized.
  def data
    unless read_attribute(:data)
       write_attribute(:data, {})
    end
    read_attribute(:data)
  end

  # Virtual attribute for mass assigning to the data hash.
  def data=(new_data)
    write_attribute(:data, new_data)
  end

  private

  # Convert number codes for inequalities into
  # the string representation:
  #  0: "="
  #  1: "<"
  #  2: ">"
  def inequality_type(number_code)
    case number_code.to_s
    when "1"
      "<"
    when "2"
      ">"
    when "<"   #Next two cases to maintain compatibility with
      "<"      #the old format.
    when ">"
      ">"
    else
      "="
    end
  end

  # Merge extra data params for example from
  # Task or Userfile custom filter.
  def self.merge_data_params(extra) #:nodocs:
    (extra + DATA_PARAMS).freeze
  end


end
