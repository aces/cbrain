require 'test_helper'

class UserfilesControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:userfiles)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_userfile
    assert_difference('Userfile.count') do
      post :create, :userfile => { }
    end

    assert_redirected_to userfile_path(assigns(:userfile))
  end

  def test_should_show_userfile
    get :show, :id => userfiles(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => userfiles(:one).id
    assert_response :success
  end

  def test_should_update_userfile
    put :update, :id => userfiles(:one).id, :userfile => { }
    assert_redirected_to userfile_path(assigns(:userfile))
  end

  def test_should_destroy_userfile
    assert_difference('Userfile.count', -1) do
      delete :destroy, :id => userfiles(:one).id
    end

    assert_redirected_to userfiles_path
  end
end
