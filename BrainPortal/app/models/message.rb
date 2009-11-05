
#
# CBRAIN Project
#
# $Id$
#

# This class provides a asynchronous communication mechanism
# between any user, group and process to any CBRAIN user.
class Message < ActiveRecord::Base

  Revision_info="$Id$"

  belongs_to :user
  
  # Send a new message to a user, the users of a group, or a site.
  #
  # The +destination+ argument can be a User, a Group, or a Site.
  #
  # Potential options are +type+, +header+, +description+,
  # +variable_text+, +expiry+ and +critical+.
  #
  # The +type+ option should be one of :notice, :error or :system.
  # The +description+ and +var_text+ are optional. An +expiry+
  # date can also be provided, such that unacknowledged messages
  # disappear from view when they are no longer relevent (for
  # instance, for system broadcast messages).
  #
  # This method will create and update a single Message object for
  # multiple successive calls that have the same +type+, +header+
  # and +description+ arguments, and will concatenate
  # and timestamps the successive +var_text+ messages into it.
  #
  # To make the +var_text+ look good, make sure that if your provide
  # multiple lines of text (a list, for instance) the first line
  # is different, as it will be the one that gets prepended with
  # the timestamp.
  #
  # The method returns the list of the messages objects created,
  # updated or simply found (if no update occured).
  def self.send_message(destination, params = {})
    type         = params[:message_type]  || params["message_type"] || :notice
    header       = params[:header]        || params["header"]
    description  = params[:description]   || params["description"]
    var_text     = params[:variable_text] || params["variable_text"]
    expiry       = params[:expiry]        || params["expiry"]
    critical     = params[:critical]      || params["critical"] || false

    # Find the group associated with the destination
    group = case destination
              when Group, User, Site
                destination.own_group
              else
                cb_error "Destination not acceptable for send_message."
            end

    # Stringify 'type' we can call with either :notice or 'notice'
    type = type.to_s unless type.is_a? String

    # Consistentize(!) all messages without a description and/or var_text
    description = nil if description.blank?
    var_text    = nil if var_text.blank?

    # Select the list of users in a group; a special case is made when the
    # group contains only one user along with 'admin', in that case
    # admin is rejected.
    allusers = group.users
    if group.name != 'admin' && allusers.size == 2
      allusers.reject! { |u| u.login == 'admin' }
    end

    # What the method returns
    messages_sent = []

    # Send to all selected users
    allusers.each do |user|

      # Find or create message object
      mess = user.messages.find(
               :first,
               :conditions => {
                   :message_type => type,
                   :header       => header,
                   :description  => description,
                   :read         => false,
                   :critical     => critical 
               }
             ) || 
             Message.new(
               :user_id      => user.id,
               :message_type => type,
               :header       => header,
               :description  => description,
               :expiry       => expiry,
               :read         => false,
               :critical     => critical 
             )
      
      # If the message is a pure repeat of an existing message,
      # do nothing. Question: do we mark it as unread?
      if var_text.blank? && ! mess.new_record?
        messages_sent << mess
        #mess.read = false; mess.save
        next
      end
        
      # Prepare new variable text
      unless var_text.blank?
        mess.append_variable_text(var_text)
      end

      mess.read      = false
      mess.last_sent = Time.now
      mess.display   = true
      mess.save

      messages_sent << mess
    end

    messages_sent
  end
  
  #Instance method version of send_message.
  #Allows one to create an object and set its attributes,
  #then send it to +destination+.
  def send_me_to(destination)
    Message.send_message(destination, self.attributes)
  end

  # Given an existing message, send it to other users/group.
  # If the destination users already have the message, nothing
  # is done.
  def forward_to_group(destination)

    # Try to send message to everyone; by setting the var_text to nil,
    # we won't change messages already sent, but we will create
    # new message for new users with a variable_text that is blank.
    found        = self.class.send_message(destination, 
                                    :message_type => self.message_type,
                                    :header       => self.header,
                                    :description  => self.description)

    # Now, if the current message DID have a var_text, we need to copy it to
    # the new messages just sent; these will be detected by
    # the fact that their own variable_text is blank.
    var_text = self.variable_text
    unless var_text.blank?
      found.each do |mess|
        next unless mess.variable_text.blank?
        mess.variable_text = var_text
        mess.save
      end
    end

    found
  end

  # Sends an internal error message where the main context
  # is an exception object.
  def self.send_internal_error_message(destination,header,exception)
    Message.send_message(destination,
      :message_type  => :error,
      :header  => "Internal error: #{header}",

      :description  => "An internal error occured inside the CBRAIN code.\n"     +
                       "Please let the CBRAIN development team know about it,\n" +
                       "as this is not supposed to go unchecked.\n"              +
                       "The last 30 caller entries are in attachement.\n",

      :variable_text  => "#{exception.class.to_s}: #{exception.message}\n" +
                          exception.backtrace[0..30].join("\n") + "\n"
    )
  end

  # Will append the text document in argument to the
  # variable_text attribute, prefixing it with a
  # timestamp.
  def append_variable_text(var_text = nil)
    return if var_text.blank?

    varlines = var_text.split(/\s*\n/)
    varlines.pop   while varlines.size > 0 && varlines[-1] == ""
    varlines.shift while varlines.size > 0 && varlines[0]  == ""

    # Append to existing variable text
    current_text = self.variable_text
    current_text = "" if current_text.blank?
    if varlines.size > 0
      timestamp    = Time.now.strftime("[%Y-%m-%d %H:%M:%S]")
      current_text += timestamp + " " + varlines[0] + "\n"
      varlines.shift
      current_text += varlines.join("\n") + "\n" if varlines.size > 0
    end

    # Reduce size if necessary
    while current_text.size > 65500 && current_text =~ /\n/   # TODO: archive ?
      current_text.sub!(/^[^\n]*\n/,"")
    end

    # Update and create message
    self.variable_text = current_text
  end
  
end
