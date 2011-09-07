
# ActiveRecord-specific CBRAIN exceptions
class CbrainDeleteRestrictionError < ActiveRecord::DeleteRestrictionError
  attr_reader :message
  
  def initialize(message)
    @message=message
  end
end

