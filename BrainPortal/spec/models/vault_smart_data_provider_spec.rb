
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

require 'rails_helper'

describe VaultSmartDataProvider do
  let(:vault_smart_data_provider) {create(:vault_smart_data_provider)}

  describe "#after_initialize_select_provider" do

    it "should receive select_local_or_network_provider" do
      expect(vault_smart_data_provider).to receive(:select_local_or_network_provider)
      vault_smart_data_provider.after_initialize_select_provider
    end

  end

end

