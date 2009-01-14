require 'test_helper'

class UserfileTest < ActiveSupport::TestCase
  # Replace this with your real tests
  fixtures :userfiles, :users
  
  def test_should_not_allow_same_userfile_for_same_user
    t = Userfile.new(:name  => 'file', :user_id  => 1)
    assert t.save, "Couldn't save new file"
    t2 = Userfile.new(:name  => 'file', :user_id  => 1)
    assert !t2.save, "Saved a non-unique file to same user."
  end
  
  def test_should_allow_same_userfile_for_different_users
    t = Userfile.new(:name  => 'file', :user_id  => 1)
    assert t.save, "Couldn't save new file"
    t2 = Userfile.new(:name  => 'file', :user_id  => 2)
    assert t2.save, "Couldn't save same file to different user."
  end
  
  def test_filter_names
    assert_equal Userfile.get_filter_name('jiv', nil), 'file:jiv'
    assert_equal Userfile.get_filter_name('minc', nil), 'file:minc'
    assert_equal Userfile.get_filter_name('name_search', 'hello'), 'name:hello'
    assert_equal Userfile.get_filter_name('tag_search', 'hello'), 'tag:hello'  
  end
  
  def test_file_creation_and_destruction
    file = Userfile.new(:name  => 'file', :user_id  => users(:users_001).id)
    file.content = '1234'
    assert file.save, "Couldn't save new file."
    assert(File.exists?(file.vaultname), 'File content not saved.')
    assert file.destroy
    assert(!File.exists?(file.vaultname), 'File content not deleted')
  end
end
