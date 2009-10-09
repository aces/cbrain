class Message < ActiveRecord::Base
  belongs_to :user
  
  #Send a new message to a group.
  def self.send_message(group, type, header, desc = nil, var_text = nil, expiry = nil)
    Group.find(group).users.each do |user|
      mess = user.messages.find(:first, :conditions  => {:header  => header, :description  => desc, :message_type  => type, :read  => false}) || 
                Message.new(:header  => header, :message_type  => type, :description  => desc, :expiry  => expiry, :read  => false, :user_id  => user.id)
      
      current_text = mess.variable_text
      current_text = "" if current_text.blank?
      lines = var_text.split(/\s*\n/)
      lines.pop while lines.size > 0 && lines[-1] == ""

      var_text = lines.join("\n") + "\n"
      current_text += Time.now.strftime("[%Y-%m-%d %H:%M:%S] ") + var_text
      while current_text.size > 65500 && current_text =~ /\n/   # TODO: archive ?
        current_text.sub!(/^[^\n]*\n/,"")
      end
      mess.variable_text = current_text
      mess.save
    end
  end
  
end
