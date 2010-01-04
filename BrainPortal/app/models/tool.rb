
#
# CBRAIN Project
#
# Task controller for the BrainPortal interface
#
# Original author: Angela McCloskey
#
# Revision_info="$Id$"
#

class Tool < ActiveRecord::Base
  Revision_info="$Id$"
  
  belongs_to :user
  belongs_to :group
  has_and_belongs_to_many :bourreaux
end
