require 'test_helper'

class UserPreferencesControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:user_preferences)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_user_preference
    assert_difference('UserPreference.count') do
      post :create, :user_preference => { }
    end

    assert_redirected_to user_preference_path(assigns(:user_preference))
  end

  def test_should_show_user_preference
    get :show, :id => user_preferences(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => user_preferences(:one).id
    assert_response :success
  end

  def test_should_update_user_preference
    put :update, :id => user_preferences(:one).id, :user_preference => { }
    assert_redirected_to user_preference_path(assigns(:user_preference))
  end

  def test_should_destroy_user_preference
    assert_difference('UserPreference.count', -1) do
      delete :destroy, :id => user_preferences(:one).id
    end

    assert_redirected_to user_preferences_path
  end
end
