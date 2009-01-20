require 'test_helper'

class UserStoriesTest < ActionController::IntegrationTest
  # fixtures :your, :models
  
  fixtures :users

  # Replace this with your real tests.
  def test_admin_creates_and_edits_a_user
    get home_path
    assert_redirected_to login_path
    
    admin = users(:users_001)
    post_via_redirect session_path, :login  => admin.login, :password  => 'wrong password'
    assert_equal "Invalid user name or password.", flash[:error]
    assert_nil session[:user_id]
    assert_template 'new'
    
    post_via_redirect session_path, :login  => admin.login, :password  => 'admin'
    assert_equal "Logged in successfully", flash[:notice]
    assert_equal session[:user_id], admin.id
    assert_equal path, home_path
    
    get users_path
    assert_response :success
    assert_template 'index'
    
    get new_user_path
    assert_response :success
    assert_template 'new'
    
    assert_difference('User.count') do
      post users_path, :user  => {:full_name  => 'Test User 1234xyz', :login => 'abcd1234', :email  => 'test@test',
                                    :password  => 'abcd1234', :password_confirmation  => 'abcd1234', :role  => 'user'}
      
    end
    assert_redirected_to users_path
    
    new_user = User.find_by_login('abcd1234')
    get edit_user_path(new_user)
    assert_response :success
    assert_template 'edit'
    
    put user_path(new_user), :user  => {:role  => 'manager'}
    assert_redirected_to user_path(new_user.id)
    assert 'manager', User.find_by_login('abcd1234').role
    
    get logout_path
    assert_redirected_to login_path
    assert_nil session[:user_id]
    
    User.find_by_login('abcd1234').destroy 
  end
  
  def test_user_can_login_upload_and_delete_a_file
    user = create_user(:login  => 'test1234', :password  => 'abcd', :password_confirmation  => 'abcd', :role  => :user)
    
    post_via_redirect session_path, :login  => user.login, :password  => user.password
    assert_equal "Logged in successfully", flash[:notice]
    assert_equal session[:user_id], user.id
    assert_equal path, home_path
    
    get userfiles_path
    assert_response :success
    assert_template 'index'
    
    filename = 'test__xxx__yyy__1234321.txt'
    assert !Userfile.find_by_name(filename)
    
    assert_difference('Userfile.count') do
      post userfiles_path, :upload_file  => fixture_file_upload("files/#{filename}")
    end
    
    vaultname = Userfile.find_by_name(filename).vaultname
    assert(File.exists?(vaultname), 'File content not saved.')
    assert_redirected_to userfiles_path
    
    assert_difference('Userfile.count', -1) do
      post operation_userfiles_path, {:operation  => 'delete', :filelist  => [Userfile.find_by_name(filename).id]}
    end
    
    assert(!File.exists?(vaultname), 'File content not deleted.')
    assert_redirected_to userfiles_path
    
    user.destroy
  end
  
  private
  
  def create_user(options = {})
    record = User.new({ :login => 'quire', :email => 'quire@example.com', :password => 'quire', :password_confirmation => 'quire', :role => 'admin', :full_name  => 'Q Uire' }.merge(options))
    record.save
    record
  end
end
