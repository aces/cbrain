
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

#This model represents a user defined filter. This is an abstract class, not meant
#to be used directly, but instead to be subclassed for the particular
#resource to be filtered. The most critical aspect in the subclass
#is its redefinition of the method filter_scope.
#
#=*IMPORTANT*: Naming conventions
#[*Controller*] The name of the subclass should be the camelcased name of
#               of the filtered resource as it appears in its controller. E.g.
#               UserfileCustomFilter filters on the UserfilesController,
#               TaskCustomFilter filters on the TasksController. Alternatively,
#               the method filtered_class_controller can be redefined to return the
#               the name of the controller being filtered on.
#[<b>Partial for new and edit actions</b>] This should saved in app/view/custom_filter/ and
#                                          should match the underscored version of the class
#                                          name. E.g. _userfile_custom_filter.html.erb for
#                                          UserfileCustomFilter.
#[<b>Type parameter</b>] A type parameter will be sent to the new and create actions of the
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

  include DateRangeRestriction

  serialize_as_indifferent_hash :data

  belongs_to :user

  validates_presence_of   :name
  validates_uniqueness_of :name, :scope  => [:user_id, :type]
  validates_format_of     :name, :with => /\A[\w\-\=\.\+\?\!\s]*\z/,
                                 :message  => 'only the following characters are valid: alphanumeric characters, spaces, _, -, =, +, ., ?, !'



  ########################################
  # Serialized 'data' attribute wrappers #
  ########################################

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



  ##########################################
  # Common Custom Attributes For Filtering #
  ##########################################

  # A Custom filter have a hash 'data' containing the filter parameters
  # The DATA_PARAMS array is used to whitelist these params.
  # This here defines just a set of generic attributes that together
  # implement filtering by created_at or updated_at.
  #
  # This structure must match the argument syntax of
  # the permit() method of ActionController::Parameters
  # Subclasses must provide their own constant DATA_PARAMS
  # with added values.
  DATA_PARAMS =
  [
    # Attributes for filtering, available for all subclasses
    :date_attribute,
    :absolute_or_relative_from,
    :absolute_or_relative_to,
    :relative_from,
    :relative_to,
    :absolute_from,
    :absolute_to,
  ]



  ######################################
  # Validation of Filtering Attributes #
  ######################################

  validate :valid_data_date_structure

  # Do some validation on the date range filtering
  def valid_data_date_structure #:nodoc:
    error_mess = check_filter_date(
      self.data["date_attribute"],
      self.data["absolute_or_relative_from"], self.data["absolute_or_relative_to"],
      self.data["absolute_from"],             self.data["absolute_to"],
      self.data["relative_from"],             self.data["relative_to"]
    )

    return true if error_mess.blank?
    errors.add(:base, error_mess)
    return false
  end



  ############################
  # Filtering Scope Builders #
  ############################

  # Returns the name of the controller of the resource being filtered.
  def filtered_class_controller
    @filtered_class_controller ||= self.class.to_s.sub(/CustomFilter\z/, "").tableize
  end

  # Returns the table name associated with the filters.
  # This is generally like the contoller name, but it COULD be
  # different. E.g. tasks vs cbrain_tasks
  def target_filtered_table
    filtered_class_controller
  end

  # Main method used for custom filtering. Should be redefined in subclasses to
  # modify +scope+ according to the filter parameters and return it.
  def filter_scope(scope)
    scope = scope_date(scope) if self.data_date_attribute.present?
    scope
  end

  # Generic utility to add a filtering rule based on a standard
  # +attribute+ of the model being filtered. Single or multiple values
  # are allowed.
  def filter_by_attribute(scope, attribute, values, filtered_table = target_filtered_table())
    values = Array(values).map(&:presence).compact
    return scope if values.blank?
    values = values[0] if values.size == 1
    scope.where("#{filtered_table}.#{attribute}" => values)
  end

  # Given a data attribute xyz, calls :data_xyz
  # and returned a cleaned array where blanks are removed.
  def cleaned_array_for_attribute(attribute)
    Array(self.send("data_#{attribute}"))
      .map(&:presence)
      .compact
  end

  private

  # Return +scope+ modified to filter the CbrainTask entry's dates.
  def scope_date(scope)
    date_attribute        = self.data_date_attribute
    mode_is_absolute_from = self.data_absolute_or_relative_from == "absolute"
    mode_is_absolute_to   = self.data_absolute_or_relative_to   == "absolute"
    absolute_from         = self.data_absolute_from
    absolute_to           = self.data_absolute_to
    relative_from         = self.data_relative_from
    relative_to           = self.data_relative_to
    table_name            = self.target_filtered_table()

    scope = add_time_condition_to_scope(scope, table_name,
            mode_is_absolute_from, mode_is_absolute_to,
            absolute_from,         absolute_to,
            relative_from,         relative_to,
            date_attribute)
  end



  #############
  # Utilities #
  #############

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



  #############################################
  # DATA Attributes Accessor Method Builders  #
  #############################################

  protected

  # Utility to merge a set of DATA_PARAMS
  # with the ones in the superclass. To
  # be invoked by a subclass.
  def self.merge_data_params(extra) #:nodoc:
    (DATA_PARAMS + extra).freeze
  end

  # Define a getter and setter method for each keys
  # in the filtered attributes list.
  def self.data_setter_and_getter(data_params=DATA_PARAMS)
    data_params.map {|x| x.is_a?(Hash) ? x.keys : x}.flatten.each do |param|

      #puts_red "Class #{self} building accessor methods for #{param}"

      # Define getter method
      define_method("data_#{param}") do
        self.data[param]
      end

      # Define setter method
      define_method("data_#{param}=") do |val|
        self.data[param] = val
      end

    end
  end

  self.data_setter_and_getter(DATA_PARAMS) # see at end of file!

end
