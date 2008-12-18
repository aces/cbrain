require 'test_helper'

class GroupTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_should_not_create_empty_group
    group = Group.new
    assert !group.valid?, "Empty group considered valid."
  end
  
  def test_should_not_create_group_without_institution
    group = Group.new(:name => 'Evans Lab')
    assert !group.valid?, "Group without name considered valid."
  end
  
  def test_should_create_group_with_institution_and_name
    group = Group.new(:name  => 'Evans Lab', :institution_id  =>  1)
    assert group.valid?
  end
  
end
