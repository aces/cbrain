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
  
  fixtures :users
  
  def test_collection_creation_and_destruction_for_tar
    col = FileCollection.new(:content  => File.read('test/fixtures/files/tarek.tar.gz'),
                              :user_id  => users(:users_001).id,
                              :name  => 'tarek.tar.gz')
                              
    archive_size = IO.popen("tar tf test/fixtures/files/tarek.tar.gz").readlines.size
    
    assert_difference('Userfile.count') do
      col.extract_collection
    end
    assert File.directory?(col.vaultname)
    
    assert_equal col.size, archive_size
    
    assert_difference('Userfile.count', -1) do
      col.destroy      
    end
    assert !File.directory?(col.vaultname)
  end
  
  def test_collection_creation_and_destruction_for_zip
    col = FileCollection.new(:content  => File.read('test/fixtures/files/myzip.zip'),
                              :user_id  => users(:users_001).id,
                              :name  => 'myzip.zip')
                              
    archive_size = IO.popen("unzip -l test/fixtures/files/myzip.zip").readlines.map(&:chomp)[3..-3].size

    assert_difference('Userfile.count') do
      col.extract_collection
    end
    assert File.directory?(col.vaultname)

    assert_equal col.size, archive_size

    assert_difference('Userfile.count', -1) do
      col.destroy      
    end
    assert !File.directory?(col.vaultname)
  end
  
  def test_size_formating
    col = FileCollection.new(:size  => 3)
    
    assert_equal col.format_size, "3 files"
  end
  
  def test_collection_merge 
    col1 = FileCollection.new(:content  => File.read('test/fixtures/files/tarek.tar.gz'),
                              :user_id  => users(:users_001).id,
                              :name  => 'tarek.tar.gz')
    col2 = FileCollection.new(:content  => File.read('test/fixtures/files/myzip.zip'),
                              :user_id  => users(:users_001).id,
                              :name  => 'myzip.zip')
    col1.extract_collection
    col2.extract_collection
    
    col3 = FileCollection.new(:user_id  => users(:users_001).id)
    
    assert_difference('Userfile.count') do
      status = col3.merge_collections([col1.id, col2.id])
    end
    
    assert File.directory?(col3.vaultname)
    
    assert_equal col3.list_files.size, (col1.size + col2.size)
    
    col1.destroy
    col2.destroy
    assert_difference('Userfile.count', -1) do
      col3.destroy
    end

    assert !File.directory?(col3.vaultname)
  end                      
end