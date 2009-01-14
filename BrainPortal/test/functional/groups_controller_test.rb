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
  end

  def test_should_get_new
    get :new, {}, {:user_id  => users(:users_001).id}
    assert_response :success
  end

  def test_should_create_group
    assert_difference('Group.count') do
      post :create, {:group => {:name  => 'group', :institution_id  => institutions(:institutions_001).id }}, {:user_id  => users(:users_001).id}
    end

    assert_redirected_to groups_path
  end

  def test_should_get_edit
    get :edit, {:id => groups(:groups_001).id}, {:user_id  => users(:users_001).id}
    assert_response :success
  end

  def test_should_update_group
    put :update, {:id => groups(:groups_001).id, :group => {:name  => 'other group'}}, {:user_id  => users(:users_001).id}
    assert_redirected_to groups_path
  end

  def test_should_destroy_group
    assert_difference('Group.count', -1) do
      delete :destroy, {:id => groups(:groups_001).id}, {:user_id  => users(:users_001).id}
    end

    assert_redirected_to groups_path
  end
end
