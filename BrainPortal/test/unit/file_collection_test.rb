#
# CBRAIN Project
#
# File collection unit tests
#
# Original author: Tarek Sherif
#
# $Id$
#
require 'test_helper'

class FileCollectionTest < ActiveSupport::TestCase
  
  fixtures :users, :data_providers
  
  def test_collection_creation_and_destruction_for_tar
    col = FileCollection.new( :user_id  => users(:users_001).id,
                              :name  => 'tarek.tar.gz')
    give_data_provider_id(col)
    col.extract_collection_from_archive_file('test/fixtures/files/tarek.tar.gz')
    assert File.directory?(col.cache_full_path)
                              
    archive_size = IO.popen("tar tf test/fixtures/files/tarek.tar.gz","r").readlines.size
    assert_equal col.size, archive_size
    
    assert_difference('Userfile.count', -1) do
      col.destroy      
    end
    assert !File.directory?(col.cache_full_path)
  end
  
  def test_collection_creation_and_destruction_for_zip
    col = FileCollection.new( :user_id  => users(:users_001).id,
                              :name  => 'myzip.zip')
    give_data_provider_id(col)
    col.extract_collection_from_archive_file('test/fixtures/files/myzip.zip')
    assert File.directory?(col.cache_full_path)
                              
    archive_size = IO.popen("unzip -l test/fixtures/files/myzip.zip").readlines.map(&:chomp)[3..-3].size
    assert_equal col.size, archive_size

    assert_difference('Userfile.count', -1) do
      col.destroy      
    end
    assert !File.directory?(col.cache_full_path)
  end
  
  def test_size_formating
    col = FileCollection.new(:size  => 3)
    give_data_provider_id(col)
    
    assert_equal col.format_size, "3 files"
  end
  
  def test_collection_merge 
    col1 = FileCollection.new(:user_id  => users(:users_001).id,
                              :name  => 'tarek.tar.gz')
    give_data_provider_id(col1)
    col1.extract_collection_from_archive_file('test/fixtures/files/tarek.tar.gz')

    col2 = FileCollection.new(:user_id  => users(:users_001).id,
                              :name  => 'myzip.zip')
    give_data_provider_id(col2)
    col2.extract_collection_from_archive_file('test/fixtures/files/myzip.zip')
      
    col3 = FileCollection.new(:user_id  => users(:users_001).id)
    give_data_provider_id(col3)
    
    assert_difference('Userfile.count') do
      status = col3.merge_collections([col1.id, col2.id])
    end
    
    assert File.directory?(col3.cache_full_path)
    
    assert_equal col3.list_files.size, (col1.size + col2.size)
        
    assert_difference('Userfile.count', -3) do
      col1.destroy
      col2.destroy
      col3.destroy
    end

    assert !File.directory?(col3.cache_full_path)
  end      
  
  def test_directory_flattening
    col1 = FileCollection.new(:user_id  => users(:users_001).id,
                              :name  => 'rename.tar')
    give_data_provider_id(col1)
    col1.extract_collection_from_archive_file('test/fixtures/files/rename.tar')

    assert File.directory?(col1.cache_full_path)
    
    col1.list_files.map(&:name).each do |file|
      assert file !~ /^one\//
    end
    
    assert !File.directory?(col1.cache_full_path + 'one')
    
    assert_difference('Userfile.count', -1) do
      col1.destroy
    end

    assert !File.directory?(col1.cache_full_path)
  end                

  def give_data_provider_id(userfile)
    return if userfile.data_provider_id
    unless self.instance_variable_defined?('@prov_id')
      prov = DataProvider.find_by_name("TestVault") || DataProvider.find(:first)
      @prov_id = prov.id
    end
    userfile.data_provider_id = @prov_id
  end

end
