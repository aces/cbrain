require 'test_helper'

class GroupTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_should_not_create_empty_group
    group = Group.new
    assert !group.valid?, "Empty group considered valid."
  end
  
  def test_should_not_create_group_with_invalid_name
    group = Group.new(:name => '/a/@% $')
    assert !group.valid?, "Group with bad name considered valid?"
  end
  
end
