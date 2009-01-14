require 'test_helper'

class InstitutionsControllerTest < ActionController::TestCase
  
  fixtures :institutions, :users
  
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

  def test_should_create_institution
    assert_difference('Institution.count') do
      post :create, {:institution => {:name  => 'mcgill' }}, {:user_id  => users(:users_001).id}
    end

    assert_redirected_to institutions_path
  end

  def test_should_get_edit
    get :edit, {:id => institutions(:institutions_001).id}, {:user_id  => users(:users_001).id}
    assert_response :success
  end

  def test_should_update_institution
    put :update, {:id => institutions(:institutions_001).id, :institution => {:name  => 'UofA' }}, {:user_id  => users(:users_001).id}
    assert_redirected_to institutions_path
  end

  def test_should_destroy_institution
    assert_difference('Institution.count', -1) do
      delete :destroy, {:id => institutions(:institutions_001).id}, {:user_id  => users(:users_001).id}
    end

    assert_redirected_to institutions_path
  end
end
