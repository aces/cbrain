require 'test_helper'

class SitesControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:sites)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_site
    assert_difference('Site.count') do
      post :create, :site => { }
    end

    assert_redirected_to site_path(assigns(:site))
  end

  def test_should_show_site
    get :show, :id => sites(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => sites(:one).id
    assert_response :success
  end

  def test_should_update_site
    put :update, :id => sites(:one).id, :site => { }
    assert_redirected_to site_path(assigns(:site))
  end

  def test_should_destroy_site
    assert_difference('Site.count', -1) do
      delete :destroy, :id => sites(:one).id
    end

    assert_redirected_to sites_path
  end
end
