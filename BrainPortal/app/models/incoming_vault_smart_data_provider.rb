
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

# This class implements a 'wrapper' data provider that
# acts either as a IncomingVaultLocalDataProvider or a IncomingVaultSshDataProvider
# depending on whether or not the current hostname matches
# the value of the attribute remote_host.
#
# This means that in the case where the current Rails application
# runs on the same machine as the data provider, the faster
# and more efficient VaultLocalDataProvider will be used.
class IncomingVaultSmartDataProvider < DataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include SmartDataProviderInterface

  after_initialize :after_initialize_select_provider

  def after_initialize_select_provider #:nodoc:
    self.select_local_or_network_provider(IncomingVaultLocalDataProvider,IncomingVaultSshDataProvider)
  end
  
  # this returns the category of the data provider -- used in view for admins
  def self.pretty_category_name
    "Incoming Vault Types"
  end

end

