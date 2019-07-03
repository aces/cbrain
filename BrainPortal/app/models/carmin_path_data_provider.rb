
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

# This is basically a VaultSmartDataProvider.
class CarminPathDataProvider < IncomingVaultSmartDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Carmin"
  end

  # This method is used by the CARMIN controller to
  # find the storage userfile associated with a CARMIN path.
  #
  # Given a path such as 'abcd/xyz/hello.txt', it will
  # search for and return the FileCollection 'abcd' belonging to +user+
  # on the current data provider, and return "xyz/hello.txt" as
  # a Pathname object. The FileCollection object might be
  # a new record, not yet saved.
  #
  # If the given path has only one component, the returned
  # object will be the first match in the database, or
  # a Userfile object which will also be a new record. Note
  # that in the latter case, objects of class Userfile cannot be
  # saved, so it's expected that the user of the method will
  # change the object to a proper subclass before saving it.
  def carmin_path_to_userfile_and_subpath(path, user) #:nodoc:
    cb_error "CARMIN path is illegal: #{path}" if path.blank?
    path = Pathname.new(path)
    cb_error "CARMIN path is not relative: #{path}" unless path.relative?
    components     = path.each_filename.to_a
    userfile_name  = components.shift
    subpath        = Pathname.new("").join(*components)
    userfile_class = subpath.to_s.blank? ? Userfile : FileCollection # not SingleFile!
    userfile       = userfile_class.find_or_initialize_by(
                       :name             => userfile_name,
                       :user_id          => user.id,
                       :data_provider_id => self.id,
                     )
    return userfile, subpath
  end

  # Returns the first CarminPathDataProvider that +user+
  # has access to. If the user has a prefered DP ID configured
  # and it happens to be a CarminPathDataProvider, then that's
  # the one returned.
  def self.find_default_carmin_provider_for_user(user)
    pref_id  = user.meta[:pref_data_provider_id] # in case it's a CarminPathDataProvider
    if pref_id.present?
      dp = self.find_all_accessible_by_user(user).find(pref_id) rescue nil
      return dp if dp
    end
    self.find_all_accessible_by_user(user).first
  end

end

