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
    assert_template 'userfiles/index'
    assert assigns(:userfiles)
  end

  

  def test_should_create_not_clobber_and_destroy_userfile
    filename = 'test__xxx__yyy__1234321.txt'
    assert !Userfile.find_by_name(filename)
    
    assert_difference('Userfile.count') do
      post :create, {:upload_file  => fixture_file_upload("files/#{filename}")}, {:user_id  => users(:users_001).id}
    end
    
    vaultname = Userfile.find_by_name(filename).cache_full_path
    assert(File.exists?(vaultname), 'File content not saved.')
    assert_redirected_to userfiles_path
    
    assert_no_difference('Userfile.count') do
      post :create, {:upload_file  => fixture_file_upload("files/#{filename}")}
    end 
    
    assert_difference('Userfile.count', -1) do
      post :operation, {:operation  => 'delete_files', :filelist  => [Userfile.find_by_name(filename).id]}
    end
    
    assert(!File.exists?(vaultname), 'File content not deleted.')
    assert_redirected_to userfiles_path
  end

  def test_should_get_edit
    get :edit, {:id => userfiles(:userfiles_001).id}, {:user_id  => userfiles(:userfiles_001).user.id}
    assert_response :success
    assert_template 'userfiles/edit'
    assert assigns(:userfile)
  end

  def test_should_update_userfile
    filename = 'test__xxx__yyy__1234321.txt'
    new_name = 'the_new_file'
    assert !Userfile.find_by_name(filename)
    
    assert_difference('Userfile.count') do
      post :create, {:upload_file  => fixture_file_upload("files/#{filename}")}, {:user_id  => users(:users_003).id}
    end
    
    file = Userfile.find_by_name(filename)
    
    put :update, {:id => file.id, :userfile => {:name  => new_name, :tag_ids  => [file.user.available_tags.first.id]}}
    
    file = Userfile.find_by_name(new_name)
    assert file.tags.count == 1
    assert file.tags.find(:first).id == tags(:tags_001).id
    assert file.name == new_name
    
    assert_redirected_to userfiles_path
    
    file.destroy
  end
  
  def test_view_all_with_user
    get :index, {:view_all => 'on'}, {:user_id => users(:users_005).id}
    assert !session[:view_all]
    assert_template 'userfiles/index'    
  end
  
  def test_view_all_with_admin
    get :index, {:view_all => 'on'}, {:user_id => users(:users_001).id}
    assert_equal session[:view_all], 'on'
    assert_template 'userfiles/index'
  end
  
  def test_pagination
      get :index, {}, {:user_id => users(:users_005).id}
      assert_equal session[:pagination], 'on'
      assert_equal assigns(:userfiles).class, WillPaginate::Collection
      
      
      get :index, {:pagination  => 'off'}     
      assert_equal session[:pagination], 'off'
      assert_equal assigns(:userfiles).class, Array
  end
  
  def test_minc_filtering_and_all_files
    get :index, {:search_type => 'minc', :pagination  => 'off'}, {:user_id => users(:users_003).id}
    assert_response :success
    assert_template 'userfiles/index'
    assert assigns(:userfiles).all? { |file| file.name[-4..-1] == '.mnc'}
    
    get :index, {:search_type => 'none', :pagination  => 'off'}
    assert_response :success
    assert_template 'userfiles/index'
    assert_equal assigns(:userfiles).size, users(:users_003).userfiles.size
  end

  def test_jiv_filtering
    get :index, {:search_type => 'jiv', :pagination  => 'off'}, {:user_id => users(:users_003).id}
    assert_response :success
    assert_template 'userfiles/index'
    assert assigns(:userfiles).all? { |file| file.name =~ /\.header|\.raw_byte(\.gz)?$/ }
  end
  
end
