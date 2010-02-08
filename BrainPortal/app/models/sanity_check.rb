class SanityCheck < ActiveRecord::Base
  validates_presence_of :revision_info
end
