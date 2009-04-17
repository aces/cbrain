require 'test_helper'

class GroupsControllerTest < ActionController::TestCase
  
  fixtures :groups, :users, :institutions
  
  def test_should_not_get_index_without_user
    get :index
    assert_redirected_to login_path
  end
  
  def test_should_not_get_index_without_admin
    get :index, {}, {:user_id  => users(:users_005).id}
    assert_response 401
  end
  
  def test_should_get_index_with_admin_user
    get :index, {}, {:user_id  => users(:users_001).id}
    assert_response :success
    assert_template 'groups/index'
  end
  
  def test_should_not_show_without_user
    get :show, {:id => groups(:groups_001).id}
    assert_redirected_to login_path
  end
  
  def test_should_not_show_without_admin
    get :show, {:id => groups(:groups_001).id}, {:user_id  => users(:users_005).id}
    assert_response 401
  end
  
  def test_should_show_with_admin_user
    get :show, {:id => groups(:groups_001).id}, {:user_id  => users(:users_001).id}
    assert_response :success
    assert_template 'groups/show'
  end

  def test_should_not_get_new_without_user
    get :new
    assert_redirected_to login_path
  end
  
  def test_should_not_get_new_without_admin
    get :new, {}, {:user_id  => users(:users_005).id}
    assert_response 401
  end

  def test_should_get_new_with_admin_user
    get :new, {}, {:user_id  => users(:users_001).id}
    assert_response :success
    assert_template 'groups/new'
  end

  def test_should_not_create_without_user
    assert_no_difference('Group.count') do
      post :create, {:group => {:name  => 'group', :institution_id  => institutions(:institutions_001).id }}
    end    
    
    assert_redirected_to login_path
  end
  
  def test_should_not_create_without_admin
    assert_no_difference('Group.count') do
      post :create, {:group => {:name  => 'group', :institution_id  => institutions(:institutions_001).id }}, {:user_id  => users(:users_005).id}
    end    
    
    assert_response 401
  end

  def test_should_create_group_with_admin_user
    assert_difference('Group.count') do
      post :create, {:group => {:name  => 'group', :institution_id  => institutions(:institutions_001).id }}, {:user_id  => users(:users_001).id}
    end

    assert_redirected_to groups_path
  end

  def test_should_not_get_edit_without_user
    get :edit, {:id => groups(:groups_001).id}
    assert_redirected_to login_path
  end
  
  def test_should_not_get_edit_without_admin
    get :edit, {:id => groups(:groups_001).id}, {:user_id  => users(:users_005).id}
    assert_response 401
  end

  def test_should_get_edit_with_admin_user
    get :edit, {:id => groups(:groups_001).id}, {:user_id  => users(:users_001).id}
    assert_response :success
  end

  def test_should_not_update_without_user
    oldname = groups(:groups_001).name
    put :update, {:id => groups(:groups_001).id, :group => {:name  => 'other group'}}
    assert_equal Group.find(groups(:groups_001).id).name, oldname
    assert_redirected_to login_path
  end
  
  def test_should_not_update_without_admin
    oldname = groups(:groups_001).name
    put :update, {:id => groups(:groups_001).id, :group => {:name  => 'other group'}}, {:user_id  => users(:users_005).id}
    assert_equal Group.find(groups(:groups_001).id).name, oldname
    assert_response 401
  end

  def test_should_update_group_with_admin_user
    put :update, {:id => groups(:groups_001).id, :group => {:name  => 'other group'}}, {:user_id  => users(:users_001).id}
    assert_equal Group.find(groups(:groups_001).id).name, 'other group'
    assert_redirected_to groups_path
  end
  
  def test_should_not_destroy_without_user
    assert_no_difference('Group.count') do
      delete :destroy, {:id => groups(:groups_001).id}
    end    
    
    assert_redirected_to login_path
  end
  
  def test_should_not_destroy_without_admin
    assert_no_difference('Group.count') do
      delete :destroy, {:id => groups(:groups_001).id}, {:user_id  => users(:users_005).id}
    end
    
    assert_response 401
  end

  def test_should_destroy_group_with_admin_user
    assert_difference('Group.count', -1) do
      delete :destroy, {:id => groups(:groups_001).id}, {:user_id  => users(:users_001).id}
    end

    assert_redirected_to groups_path
  end
end
