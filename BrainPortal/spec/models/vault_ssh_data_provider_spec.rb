
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

RSpec.describe VaultSshDataProvider, :type => :model do
  let(:vault_ssh_data_provider) { create(:vault_ssh_data_provider) }
  let(:userfile)                { create(:single_file, :data_provider => vault_ssh_data_provider) }
  let(:user)                    { mock_model(NormalUser) }

  describe "#is_browsable?" do
    it "should return false" do
      expect(vault_ssh_data_provider.is_browsable?).to be_falsey
    end
  end


  describe "#impl_provider_list_all" do
    let(:sftp)       { double("sftp").as_null_object }
    let(:entry)      { double("entry").as_null_object }
    let(:ssh_master) { double("master").as_null_object }

    before(:each) do
      allow(Net::SFTP).to               receive(:start).and_yield(sftp)
      allow(sftp).to                    receive_message_chain(:dir, :foreach).and_yield(entry)
      allow(entry).to                   receive(:attributes).and_return(double("atts", :symbolic_type => :regular).as_null_object)
      allow(vault_ssh_data_provider).to receive(:is_browsable?).and_return(true)
      allow(vault_ssh_data_provider).to receive(:master).and_return(ssh_master)

    end

    it "should return a cbrain error if isn't browsable" do
      allow(vault_ssh_data_provider).to receive(:is_browsable?).and_return(false)
      expect(lambda{vault_ssh_data_provider.impl_provider_list_all}).to raise_error(CbrainError)
    end

    it "should start an SFTP session" do
      expect(Net::SFTP).to receive(:start)
      vault_ssh_data_provider.impl_provider_list_all
    end
    it "should iterate through the entries in the directory" do
      expect(sftp).to receive(:dir).and_return(double.as_null_object)
      vault_ssh_data_provider.impl_provider_list_all
    end
    it "should extract the attributes for the entry" do
      expect(entry).to receive(:attributes)
      vault_ssh_data_provider.impl_provider_list_all
    end
    it "should create a new FileInfo object" do
      expect(DataProvider::FileInfo).to receive(:new).and_return(double.as_null_object)
      vault_ssh_data_provider.impl_provider_list_all
    end
    it "should return an array of FileInfo objects" do
      expect(vault_ssh_data_provider.impl_provider_list_all.all? { |fi| fi.is_a?(DataProvider::FileInfo) }).to be_truthy
    end
  end

  describe "#provider_full_path" do
    it "should return provider_full_path" do
      allow(vault_ssh_data_provider).to receive(:remote_dir).and_return("x/y/z")
      provider_full_path =
        Pathname.new("#{vault_ssh_data_provider.remote_dir}/#{userfile.user.login}/#{userfile.name}")
      expect(vault_ssh_data_provider.provider_full_path(userfile)).to eq(provider_full_path)
    end
  end


end

