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
    assert_template 'institutions/index'
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
    assert_template 'institutions/new'    
  end

  def test_should_not_create_without_user
    assert_no_difference('Institution.count') do
      post :create, {:institution => {:name  => 'institution'}}
    end    
    
    assert_redirected_to login_path
  end
  
  def test_should_not_create_without_admin
    assert_no_difference('Institution.count') do
      post :create, {:institution => {:name  => 'institution'}}, {:user_id  => users(:users_005).id}
    end    
    
    assert_response 401
  end

  def test_should_create_institution_with_admin_user
    assert_difference('Institution.count') do
      post :create, {:institution => {:name  => 'institution'}}, {:user_id  => users(:users_001).id}
    end

    assert_redirected_to institutions_path
  end

  def test_should_not_get_edit_without_user
    get :edit, {:id => institutions(:institutions_001).id}
    assert_redirected_to login_path
  end
  
  def test_should_not_get_edit_without_admin
    get :edit, {:id => institutions(:institutions_001).id}, {:user_id  => users(:users_005).id}
    assert_response 401
  end

  def test_should_get_edit_with_admin_user
    get :edit, {:id => institutions(:institutions_001).id}, {:user_id  => users(:users_001).id}
    assert_response :success
    assert_template 'institutions/edit'  
  end

  def test_should_not_update_without_user
    oldname = institutions(:institutions_001).name
    put :update, {:id => institutions(:institutions_001).id, :institution => {:name  => 'other institution'}}
    assert_equal Institution.find(institutions(:institutions_001).id).name, oldname
    assert_redirected_to login_path
  end
  
  def test_should_not_update_without_admin
    oldname = institutions(:institutions_001).name
    put :update, {:id => institutions(:institutions_001).id, :institution => {:name  => 'other institution'}}, {:user_id  => users(:users_005).id}
    assert_equal Institution.find(institutions(:institutions_001).id).name, oldname
    assert_response 401
  end

  def test_should_update_institution_with_admin_user
    put :update, {:id => institutions(:institutions_001).id, :institution => {:name  => 'other institution'}}, {:user_id  => users(:users_001).id}
    assert_equal Institution.find(institutions(:institutions_001).id).name, 'other institution'
    assert_redirected_to institutions_path
  end
  
  def test_should_not_destroy_without_user
    assert_no_difference('Institution.count') do
      delete :destroy, {:id => institutions(:institutions_001).id}
    end    
    
    assert_redirected_to login_path
  end
  
  def test_should_not_destroy_without_admin
    assert_no_difference('Institution.count') do
      delete :destroy, {:id => institutions(:institutions_001).id}, {:user_id  => users(:users_005).id}
    end
    
    assert_response 401
  end

  def test_should_destroy_institution_with_admin_user
    assert_difference('Institution.count', -1) do
      delete :destroy, {:id => institutions(:institutions_001).id}, {:user_id  => users(:users_001).id}
    end

    assert_redirected_to institutions_path
  end
end
