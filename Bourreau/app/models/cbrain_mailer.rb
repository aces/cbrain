
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

#Dummy version of the cbrain mailer for Bourreau.
#Won't send e-mails, but the class is needed for 
#Message.
class CbrainMailer < ActionMailer::Base
  
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  
  #Send an e-mail notification of a CBRAIN message.
  #Meant to be used by Message.send_message.
  def cbrain_message(users, content = {})
    @users   = users

    @subject = content[:subject] || "No subject"
    @cb_body = content[:body]    || ""  # NOTE: @body is used by Rails!
    @cb_body.gsub!(/\s+\(?\[\[.*?\]\]\)?/, "")
    
    return true if @users.blank? || @users.empty?

    emails = users.map(&:email).compact.uniq.reject { |email| email.blank? || email =~ /^(nobody|no-?reply|sink)@/i }
    return false if emails.empty?
    nil # this is where the normal mail-sending code was
  end

end
