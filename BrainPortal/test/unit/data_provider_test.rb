require 'test_helper'

class DataProviderTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_truth
    assert true
  end
  
  must "no let me save two data providers with the same name" do
    Factory.create(:data_provider, :name => "Provider A")
    bad_provider = Factory.build(:data_provider, :name => "Provider A")
    assert_false bad_provider.save
  end
end
