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
  fixtures :userfiles, :users
  
  def test_should_not_allow_same_userfile_for_same_user
    t = SingleFile.new(:name  => 'file', :user_id  => 1)
    assert t.save, "Couldn't save new file"
    t2 = SingleFile.new(:name  => 'file', :user_id  => 1)
    assert !t2.save, "Saved a non-unique file to same user."
  end
  
  def test_should_allow_same_userfile_for_different_users
    t = SingleFile.new(:name  => 'file', :user_id  => 1)
    assert t.save, "Couldn't save new file"
    t2 = SingleFile.new(:name  => 'file', :user_id  => 2)
    assert t2.save, "Couldn't save same file to different user."
  end
  
  def test_single_file_creation_and_destruction
    file = SingleFile.new(:name  => 'file', :user_id  => users(:users_001).id)
    file.content = '1234'
    assert file.save, "Couldn't save new file."
    assert(File.exists?(file.vaultname), 'File content not saved.')
    assert file.destroy
    assert(!File.exists?(file.vaultname), 'File content not deleted')
  end
  
  def test_content_methods
    file = SingleFile.new()
    content = "hello"
    file.content = content
    assert_equal file.content, content
    assert_equal file.size, content.size
  end
  
  def test_size_formatting
    file = SingleFile.new()
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
    assert_equal file.list_files, [file.name]
  end
end