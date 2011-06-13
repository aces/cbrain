#
# CBRAIN Project
#
# Single file unit tests
#
# Original author: Tarek Sherif
#
# $Id$
#
require 'test_helper'

class SingleFileTest < ActiveSupport::TestCase
  fixtures :userfiles, :users, :data_providers
  
  def test_should_not_allow_same_userfile_for_same_user
    t = SingleFile.new(:name  => 'file', :user_id  => 1)
    give_data_provider_id(t)
    assert t.save, "Couldn't save new file"
    t2 = SingleFile.new(:name  => 'file', :user_id  => 1)
    give_data_provider_id(t2)
    assert !t2.save, "Saved a non-unique file to same user."
  end
  
  def test_should_allow_same_userfile_for_different_users
    t = SingleFile.new(:name  => 'file', :user_id  => 1)
    give_data_provider_id(t)
    assert t.save, "Couldn't save new file"
    t2 = SingleFile.new(:name  => 'file', :user_id  => 2)
    give_data_provider_id(t2)
    assert t2.save, "Couldn't save same file to different user."
  end
  
  def test_single_file_creation_and_destruction
    file = SingleFile.new(:name  => 'file', :user_id  => users(:users_001).id)
    give_data_provider_id(file)
    file.cache_writehandle { |io| io.write('1234') }
    assert file.save, "Couldn't save new file."
    assert(File.exists?(file.cache_full_path), 'File content not saved.')
    assert file.destroy
    assert(!File.exists?(file.cache_full_path), 'File content not deleted')
  end
  
  def test_size_formatting
    file = SingleFile.new()
    give_data_provider_id(file)
    file.size = 5 * (10 ** 9)
    assert_equal file.format_size, '5 GB'
    file.size /= 10 ** 3
    assert_equal file.format_size, '5 MB'
    file.size /= 10 **3
    assert_equal file.format_size, '5 KB'
    file.size /= 10 **3
    assert_equal file.format_size, '5 bytes'
  end
  
  def test_file_list
    file = SingleFile.new(:name  => 'file')
    give_data_provider_id(file)
    assert_equal file.list_files.map(&:name), [file.name]
  end

  def give_data_provider_id(userfile)
    return if userfile.data_provider_id
    unless self.instance_variable_defined?('@prov_id')
      prov = DataProvider.find_by_name("TestVault") || DataProvider.first
      @prov_id = prov.id
    end
    userfile.data_provider_id = @prov_id
  end

end
