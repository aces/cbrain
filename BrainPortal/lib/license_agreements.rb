
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
      after_save :register_license_agreements
    end
  end

  def license_agreements
    self.meta[:license_agreements].presence || []
  end

  def license_agreements=(agreements)
    agrs = agreements
    unless agrs.is_a? Array
      agrs = agrs.to_s.split(/[,\s]+/).map { |a| a.sub(/\.html$/, "").gsub(/[^\w-]+/, "") }.uniq.sort
    end
    @license_agreements = agrs
  end

  def register_license_agreements
    self.meta[:license_agreements] = @license_agreements.presence
    # Unset all licenses signed when a new license is added
    User.all.each do |u|
      u.all_licenses_signed = nil
    end
  end

end
