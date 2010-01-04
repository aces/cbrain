
#
# CBRAIN Project
#
# Task controller for the BrainPortal interface
#
# Original author: Angela McCloskey
#
# $Id$
#

class Tool < ActiveRecord::Base
  belongs_to :user
  belongs_to :group
  has_and_belongs_to_many :bourreaux
end
