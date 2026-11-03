
#
# CBRAIN Project
#
# Copyright (C) 2008-2026
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

RSpec.describe DataProvidersHelper, :type => :helper do

  describe "#data_provider_type_choices" do

    # Stubs the list of classes, so that the result does not depend on which ones
    # are loaded. Nothing may load while descendants is stubbed, because Rails
    # calls it when a class defines a callback, hence the stubbed preload.
    # Loading is covered by data_provider_preload_spec.
    def stub_provider_classes(categories_by_name)
      allow(DataProvider).to receive(:preload_subclasses)
      allow(DataProvider).to receive(:descendants).and_return(
        categories_by_name.map { |name, category| double(name, :name => name, :pretty_category_name => category) }
      )
    end

    it "groups the class names by category, both sorted" do
      stub_provider_classes(
        "ZuluDataProvider"   => "Category B",
        "YankeeDataProvider" => "Category A",
        "XrayDataProvider"   => "Category B",
      )

      expect(helper.data_provider_type_choices).to eq([
        [ "Category A", [ "YankeeDataProvider" ] ],
        [ "Category B", [ "XrayDataProvider", "ZuluDataProvider" ] ],
      ])
    end

    it "leaves out the classes without a category" do
      stub_provider_classes(
        "HiddenDataProvider"  => nil,
        "VisibleDataProvider" => "Category A",
      )

      expect(helper.data_provider_type_choices).to eq([ [ "Category A", [ "VisibleDataProvider" ] ] ])
    end

    context "with the real classes" do
      let(:offered_types) { helper.data_provider_type_choices.flat_map(&:last) }

      it "offers a type admins can create" do
        expect(offered_types).to include("FlatDirSshDataProvider")
      end

      it "hides the type reserved for personal data providers" do
        expect(offered_types).not_to include("UserkeyFlatDirSshDataProvider")
      end
    end

  end

end
