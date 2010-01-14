require 'test_helper'

class CustomFiltersControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:custom_filters)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_custom_filter
    assert_difference('CustomFilter.count') do
      post :create, :custom_filter => { :name => "test_should_create_custom_filter" }
    end

    assert_redirected_to custom_filter_path(assigns(:custom_filter))
  end

  def test_should_show_custom_filter
    get :show, :id => custom_filters(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => custom_filters(:one).id
    assert_response :success
  end

  def test_should_update_custom_filter
    put :update, :id => custom_filters(:one).id, :custom_filter => { }
    assert_redirected_to custom_filter_path(assigns(:custom_filter))
  end

  def test_should_destroy_custom_filter
    assert_difference('CustomFilter.count', -1) do
      delete :destroy, :id => custom_filters(:one).id
    end

    assert_redirected_to custom_filters_path
  end
end
