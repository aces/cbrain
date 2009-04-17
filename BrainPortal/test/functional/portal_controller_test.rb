require 'test_helper'

class PortalControllerTest < ActionController::TestCase
  fixtures :users
  
  def test_should_not_get_welcome_without_user
    get :welcome
    assert_redirected_to login_path
  end
  
  def test_should_get_welcome_with_user
    get :welcome, {}, {:user_id  => users(:users_005).id}
    assert_response :success
    assert_template 'portal/welcome'
  end
end
