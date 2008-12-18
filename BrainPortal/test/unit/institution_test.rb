require 'test_helper'

class InstitutionTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  
  def test_should_not_create_empty_institution
    institution = Institution.new
    assert !institution.valid?
    assert institution.errors.invalid?(:name)
  end
  
  def test_should_create_institution_with_name_only
    institution = Institution.new(:name  => 'McGill')
    assert institution.valid?
  end
  
  def test_should_not_create_institution_with_everything_but_name
    institution = Institution.new(:city  => 'Montreal', :province  => 'Quebec', :country  => 'Canada')
    assert !institution.valid?
  end
end
