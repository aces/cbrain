
#
# CBRAIN Project
#
# Control communication channel between Rails applications
#
# Original author: Pierre Rioux
#
# $Id$
#

# The Control class implements a communication channel
# between two Rails applications. The precise list of
# attributes that are set inside the object varies depending
# on the request that is being made; right now when
# the Controls controller replies to a 'show' action,
# it fills a Control object with a populated RemoteResourceInfo
# object:
#
#     myinfo = RemoteResourceInfo.new() # acts like a Hash
#     tosend = Control.new(myinfo)
#
# When a command is sent from one RemoteResource to another,
# the Control object is filled with a RemoteCommand object:
#
#     mycom = RemoteCommand.new(blah blah) # acts like a Hash
#     tosend = Control.new(mycom)
#
# The ActiveResource layer doesn't care that the data being
# shuffled back and forth is so polymorphic.
class Control < ActiveResource::Base

  Revision_info=CbrainFileRevision[__FILE__]
  
end

