
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

# Module containing common methods for set and access the
# license agreements
module LicenseAgreements

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Check that the the class this module is being included into is a valid one.
  def self.included(includer) #:nodoc:
    unless includer <= ActiveRecord::Base
      raise "#{includer} is not an ActiveRecord model. The LicenseAgreements module cannot be used with it."
    end

    includer.class_eval do
      # License agreement is a pseudo attributes and cannot be accessed if the object is not saved.
      after_find :load_license_agreements
      validate   :valid_license_agreements?
      after_save :register_license_agreements
    end
  end

  # Returns the list of license agreements that exists for this object.
  def license_agreements
    @license_agreements ||= []
  end

  # Sets the list of license agreements that exists for this object.
  # Can be provided with an array of license names, or a single string with
  # a space-or-comma-separated list of license names.
  def license_agreements=(agreements)
    agrs = agreements
    unless agrs.is_a? Array
      agrs = agrs.to_s.split(/[,\s]+/)
    end
    agrs = agrs.map { |a| a.sub(/\.html\z/, "").gsub(/[^\w-]+/, "") }.uniq.sort
    @license_agreements = agrs
  end

  protected

  # 'after_load' callback. Loads the licenses from the meta data store.
  def load_license_agreements
    @license_agreements           = self.meta[:license_agreements].presence || []
    @_license_agreements_original = @license_agreements.dup # to determine if anything changed when saving
    true
  end

  # Returns true if the set of licenses are identifiers that
  # properly match files on the filesystem, in public/licenses/{name}.html
  def valid_license_agreements?
    invalid_licenses = license_agreements.select do |license|
      ! File.exists?(Rails.root + "public/licenses/#{license}.html")
    end

    if invalid_licenses.presence
      invalid_licenses_list = invalid_licenses.join(", ")
      self.errors.add(:base, "Some licence agreement files do not exist: #{invalid_licenses_list}\nPlease place the license file(s) in /public/licenses or unconfigure it.\n")
      return false
    end
    return true
  end

  # 'after_save' callback to write back the license agreements array
  # to the meta data store whenever the object is being saved.
  def register_license_agreements
    # To keep pre_register licenses agreement, usefull when the console is used to save the object
    new_agreements  = (license_agreements || []).sort
    orig_agreements = (@_license_agreements_original || []).sort
    return true if new_agreements == orig_agreements
    self.meta[:license_agreements] = license_agreements
    @_license_agreements_original = license_agreements
    # Unset all licenses signed when a new license is added
    User.all.each do |u|
      u.all_licenses_signed = nil
    end
    true
  end

end
