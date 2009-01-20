require File.dirname(__FILE__) + '/../test_helper'
require 'users_controller'

# Re-raise errors caught by the controller.
class UsersController; def rescue_action(e) raise e end; end

class UsersControllerTest < Test::Unit::TestCase
  # Be sure to include AuthenticatedTestHelper in test/test_helper.rb instead
  # Then, you can remove it from this and the units test.
  include AuthenticatedTestHelper

  fixtures :users

  def setup
    @controller = UsersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_allow_creation_as_admin   
    assert_difference 'User.count' do
      create_user_as_admin
      assert_redirected_to users_path
    end
  end
  
  def test_should_not_allow_creation_as_user
    assert_no_difference 'User.count' do
      create_user_as_user
      assert_response 401
    end
  end
  
  def test_should_not_allow_creation_as_manager
    assert_no_difference 'User.count' do
      create_user_as_manager
      assert_response 401
    end
  end

  def test_should_require_login_on_creation_as_admin
    assert_no_difference 'User.count' do
      create_user_as_admin(:login => nil)
      assert assigns(:user).errors.on(:login)
      assert_response :success
    end
  end

  def test_should_require_password_on_creation_as_admin
    assert_no_difference 'User.count' do
      create_user_as_admin(:password => nil)
      assert assigns(:user).errors.on(:password)
      assert_response :success
    end
  end

  def test_should_require_password_confirmation_on_creation_as_admin
    assert_no_difference 'User.count' do
      create_user_as_admin(:password_confirmation => nil)
      assert assigns(:user).errors.on(:password_confirmation)
      assert_response :success
    end
  end

  def test_should_require_email_on_creation_as_admin
    assert_no_difference 'User.count' do
      create_user_as_admin(:email => nil)
      assert assigns(:user).errors.on(:email)
      assert_response :success
    end
  end
  

  

  protected
    def create_user_as_admin(options = {})
      post :create, {:user => option_hash(options)}, {:user_id  => users(:users_001).id}
    end
    
    def create_user_as_user(options = {})
      post :create, {:user => option_hash(options)}, {:user_id  => users(:users_005).id}
    end
    
    def create_user_as_manager(options = {})
      post :create, {:user => option_hash(options)}, {:user_id  => users(:users_002).id}
    end
    
    def option_hash(options)
      { :full_name  => 'quire', :login => 'quire', :email => 'quire@example.com',
        :password => 'quire', :password_confirmation => 'quire', :role  => 'user' }.merge(options)
    end
end
