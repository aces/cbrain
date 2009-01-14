require 'test_helper'

class TagsControllerTest < ActionController::TestCase
  
  fixtures :tags, :users
  
  def test_should_not_get_index_without_user
    get :index
    assert_redirected_to login_path
  end
  
  def test_should_get_index_with_user
    get :index, {}, {:user_id => tags(:tags_001).user.id}
    assert_response :success
    assert_not_nil assigns(:tags)
  end

  def test_should_not_get_new_without_user
    get :new
    assert_redirected_to login_path 
  end
  
  def test_should_get_new_with_user
    get :new, {}, {:user_id => tags(:tags_001).user.id}
    assert_response :success
  end  

  def test_should_create_tag
    assert_difference('Tag.count') do
      post :create, {:tag => {:name  => 'tag' }}, {:user_id => tags(:tags_001).user.id}
    end

    assert_redirected_to tag_path(assigns(:tag))
  end

  def test_should_show_tag
    get :show, {:id => tags(:tags_001).id}, {:user_id => tags(:tags_001).user.id}
    assert_response :success
  end

  def test_should_get_edit
    get :edit, {:id => tags(:tags_001).id}, {:user_id => tags(:tags_001).user.id}
    assert_response :success
  end

  def test_should_update_tag
    put :update, {:id => tags(:tags_001).id, :tag => {:name  => 'tag' }}, {:user_id => tags(:tags_001).user.id}
    assert_redirected_to tag_path(assigns(:tag))
  end

  def test_should_destroy_tag
    assert_difference('Tag.count', -1) do
      delete :destroy, {:id => tags(:tags_001).id}, {:user_id => tags(:tags_001).user.id}
    end

    assert_redirected_to tags_path
  end
end
