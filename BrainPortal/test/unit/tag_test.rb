require 'test_helper'

class TagTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_should_not_save_empty_tag
    t = Tag.new
    assert !t.valid?
    assert t.errors.invalid?(:name)
    assert t.errors.invalid?(:user_id)
    assert !t.save 
  end
  
  def test_should_not_allow_same_tag_for_same_user
    t = Tag.new(:name  => 'tag', :user_id  => 1)
    assert t.save, "Couldn't save new tag"
    t2 = Tag.new(:name  => 'tag', :user_id  => 1)
    assert !t2.save, "Saved a non-unique tag to same user."
  end
  
  def test_should_allow_same_tag_for_different_users
    t = Tag.new(:name  => 'tag', :user_id  => 1)
    assert t.save, "Couldn't save new tag"
    t2 = Tag.new(:name  => 'tag', :user_id  => 2)
    assert t2.save, "Couldn't save same tag to different user."
  end
end
