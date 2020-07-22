
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




# Module containing common methods for set and access the user create, custom user-agreements
# license agreements. Differently from the original, user can create his own licenses
# The license agreements themselves are TextFiles, and the includer will
# maintain the list of TextFile IDs in the meta data store under key :custom_license_agreements
module CustomLicense

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  require 'securerandom'

  # Check that the class this module is being included into is a valid one.
  def self.included(includer) #:nodoc:
    unless includer <= ApplicationRecord
      raise "#{includer} is not an ActiveRecord model. The #{self.name} module cannot be used with it."
    end

    includer.class_eval do
      # License agreement is a pseudo attributes and cannot be accessed if the object is not saved.
      validate   :valid_custom_license_agreements?
      after_save :register_custom_license_agreements
    end
  end

  # Returns the list of license agreements that exists for this object.
  def custom_license_agreements
    @custom_license_agreements ||= load_custom_license_agreements
  end

  # Sets the list of license agreements that exists for this object.
  # This should be an array of TextFile IDs
  def custom_license_agreements=(textfile_ids)
    self.custom_license_agreements # loads them if not already loaded
    @custom_license_agreements = SingleFile.where(:id => textfile_ids).pluck(:id)
  end

  # Add a single agreement (a TextFile) to the list of agreement
  # associated with the object.
  def add_custom_license_agreement(textfile)
    current_list = self.custom_license_agreements
    current_list |= [ textfile.id ]
    self.custom_license_agreements = current_list
  end

  # Create a license file and associate it with the current object
  def register_custom_license(content, user, basename=nil)
    basename ||= "license_#{SecureRandom.uuid.to_s}.txt"
    textfile = create_custom_license_file(content, user, basename)
    custom_license_agreements |= [ textfile.id ] if textfile.present?
    textfile.addlog("License added to #{self.class} \"#{self.name}\" (ID #{self.id})")
    add_custom_license_agreement(textfile)
    register_custom_license_agreements  # save
  end

  protected

  # Loads the licenses from the meta data store.
  def load_custom_license_agreements
    @custom_license_agreements           = self.new_record? ? [] : self.meta[:custom_license_agreements].presence || []
    @_custom_license_agreements_original = @custom_license_agreements.dup # to determine if anything changed when saving
    @custom_license_agreements
  end

  # Validate that license files exists
  def valid_custom_license_agreements?
    # Verify if a license was deleted or not
    invalid_license_ids = custom_license_agreements.select { |id| !Userfile.exists?(id) }

    return true if invalid_license_ids.empty?

    pretty = invalid_license_ids.join(", ")

    self.errors.add(:base, "Some license agreement files do not exist: #{pretty}\n
                            Please inform the maintainers or admins to fix issues with files.\n")

    return false
  end

  # Utility method to create a license file for a user.
  def create_custom_license_file(content, user, basename) #:nodoc:
    file_type    = TextFile

    # Todo, adjust logic?
    dest_dp_id   = DataProvider.find_by_id(user.meta[:pref_data_provider_id]).try(:id)
    dest_dp_id ||= DataProvider.find_all_accessible_by_user(user).where(:online => true).first.try(:id)

    userfile = file_type.create!(
      :name             => basename,
      :user_id          => user.id,
      :data_provider_id => dest_dp_id,
      :group_id         => user.own_group.id
    )

    # Add content and the make immutable
    userfile.cache_writehandle { |fh| fh.write content }
    userfile.save
    userfile.immutable = true
    userfile.save
    userfile.addlog_context(self, "License created by #{user.login}")

    Message.send_message(user,
      :message_type   => 'notice',
      :header         => "License file added",
      :variable_text  => "#{userfile.pretty_type} [[#{userfile.name}][/userfiles/#{userfile.id}]]"
    )
    userfile
  end

  # Writes back the license agreements array to the meta data store
  # This is a callback invoked after an object is saved
  def register_custom_license_agreements
    return true if @custom_license_agreements.nil? # nothing to do if they were never loaded or updated
    # To keep pre_register licenses agreement, useful when the console is used to save the object
    new_agreements  = (custom_license_agreements || []).sort
    orig_agreements = (@_custom_license_agreements_original || []).sort
    return true if new_agreements == orig_agreements
    self.meta[:custom_license_agreements] = new_agreements
    true
  end

end

