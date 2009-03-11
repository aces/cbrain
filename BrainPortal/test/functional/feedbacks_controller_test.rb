require 'test_helper'

class FeedbacksControllerTest < ActionController::TestCase
  
  fixtures :feedbacks, :users
  
  def test_should_get_index_with_session
    get :index, {}, :user_id  => users(:users_005).id
    assert_response :success
    assert_not_nil assigns(:feedbacks)
  end

  def test_should_get_new
    get :new, {}, :user_id  => users(:users_005).id
    assert_response :success
  end

  def test_should_not_create_feedback_without_session
    assert_no_difference('Feedback.count') do
      post :create, :feedback => {:user_id  => users(:users_001).id, :summary  => "hello", :details  => "details"}
    end

    assert_redirected_to login_path
  end

  def test_should_show_feedback
    get :show, {:id => feedbacks(:feedbacks_001).id}, :user_id  => users(:users_005).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, {:id => feedbacks(:feedbacks_001).id}, :user_id  => feedbacks(:feedbacks_001).user.id
    assert_response :success
  end

  def test_should_update_feedback
    put :update, {:id => feedbacks(:feedbacks_001).id, :feedback => { }}, :user_id  => feedbacks(:feedbacks_001).user.id
    assert_redirected_to feedback_path(assigns(:feedback))
  end

  def test_should_destroy_feedback
    assert_difference('Feedback.count', -1) do
      delete :destroy, {:id => feedbacks(:feedbacks_001).id}, :user_id  => users(:users_005).id
    end

    assert_redirected_to feedbacks_path
  end
end
