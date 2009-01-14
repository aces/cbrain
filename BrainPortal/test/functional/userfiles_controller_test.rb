require 'test_helper'

class UserfilesControllerTest < ActionController::TestCase
  fixtures :userfiles, :users, :tags
  
  def test_should_not_get_index_without_user
    get :index
    assert_redirected_to login_path
  end
  
  def test_should_get_index_with_user
    get :index, {}, {:user_id  => users(:users_005).id}
    assert_response :success
  end

  

  def test_should_create_and_destroy_userfile
    filename = 'test__xxx__yyy__1234321.txt'
    assert !Userfile.find_by_name(filename)
    
    assert_difference('Userfile.count') do
      post :create, {:upload_file  => fixture_file_upload("files/#{filename}")}, {:user_id  => users(:users_001).id}
    end
    
    vaultname = Userfile.find_by_name(filename).vaultname
    assert(File.exists?(vaultname), 'File content not saved.')
    assert_redirected_to userfiles_path
    
    assert_difference('Userfile.count', -1) do
      post :operation, {:operation  => 'delete', :filelist  => [Userfile.find_by_name(filename).id]}, {:user_id  => users(:users_001).id}
    end
    
    assert(!File.exists?(vaultname), 'File content not deleted.')
    assert_redirected_to userfiles_path
  end

  def test_should_show_userfile
    get :show, {:id => userfiles(:userfiles_001).id}, {:user_id  => userfiles(:userfiles_001).user.id}
    assert_response :success
  end

  def test_should_get_edit
    get :edit, {:id => userfiles(:userfiles_001).id}, {:user_id  => userfiles(:userfiles_001).user.id}
    assert_response :success
  end

  def test_should_update_userfile
    put :update, {:id => userfiles(:userfiles_001).id, :userfile => {:tag_ids  => [tags(:tags_001).id]}}, {:user_id  => userfiles(:userfiles_001).user.id}
    assert userfiles(:userfiles_001).tags.count == 1
    assert userfiles(:userfiles_001).tags.find(:first).id == tags(:tags_001).id
    assert_redirected_to userfiles_path
  end

end
