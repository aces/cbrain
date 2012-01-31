
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

###################################################################
# CBRAIN ActiveRecord extensions
###################################################################
class ActiveRecord::Base

  ############################################################################
  # Pretty Type methods
  ############################################################################

  # Default 'pretty' type name for the model.
  def self.pretty_type
    self.to_s.demodulize.underscore.titleize
  end

  # Default 'pretty' type name for the object.
  def pretty_type
    self.class.pretty_type
  end

  ###################################################################
  # ActiveRecord Added Behavior For MetaData
  ###################################################################

  include ActRecMetaData # module in lib/act_rec_meta_data.rb

  ###################################################################
  # ActiveRecord Added Behavior For Logging
  ###################################################################

  include ActRecLog # module in lib/act_rec_log.rb

  ###################################################################
  # ActiveRecord Added Behavior For Data Typing
  ###################################################################

  cattr_accessor :cbrain_forced_attribute_encodings # cattr_accessor is from Rails

  # This directive adds an after_initalize() callback such that
  # attributes stored as :text in the schema are always reloaded
  # with a forced encoding. In a model:
  #
  #   force_attribute_encoding encoding_name, :att [, :att, ...]
  def self.force_text_attribute_encoding(encoding_name, *attlist)
    return unless self.table_exists?
    
    to_adjust = self.cbrain_forced_attribute_encodings ||= {}
    enc = Encoding.find(encoding_name) rescue nil
    raise "No such encoding '#{encoding_name}'." unless enc
    raise "Need a list of :text attributes to adjust." if attlist.empty?
    attlist.each do |att|
      raise "Attribute '#{att}' not a symbol?!?" unless att.is_a?(Symbol)
      colinfo = self.columns_hash[att.to_s] || self.columns_hash[att]
      raise "No such attribute '#{att}' for model #{self.name}"  unless colinfo
      raise "Attribute '#{att}' is not of type :text or :string in the DB!" unless colinfo.type == :text || colinfo.type == :string
      to_adjust[att] = encoding_name
    end
    after_initialize :adjust_forced_attribute_encodings
  end

  # Called automatically after a record is reloaded (it's an
  # after_initalize() callback) if the directive
  # force_text_attribute_encoding was used.
  def adjust_forced_attribute_encodings #:nodoc:
    to_adjust = self.class.cbrain_forced_attribute_encodings
    return true unless to_adjust
    return true if     to_adjust.empty?
    to_adjust.each do |att,enc_name|
      self.send(att).force_encoding(enc_name) rescue nil # seems to work in Rails 3.0.7, and record not ".changed?"
      #self.write_attribute(att, self.send(att).force_encoding(enc_name)) rescue nil # seems to work in Rails 3.0.7
    end
    true
  end



  ###################################################################
  # ActiveRecord Added Behavior For Serialization
  ###################################################################

  # This directive is just like ActiveRecord's serialize directive,
  # but it makes sure that the hash will be reconstructed as
  # a HashWithIndifferentAccess ; it is meant to be backwards compatible
  # with old DBs where the records were saved as Hash, so it will
  # update them as they are reloaded using a after_initialize callback.
  def self.serialize_as_indifferent_hash(*attlist)
    attlist.each do |att|
      raise "Attribute '#{att}' not a symbol?!?" unless att.is_a?(Symbol)
      serialize att, BasicObject # we use this to record which attributes are to be indifferent.
      #serialize att
    end
    after_initialize :ensure_serialized_hash_are_indifferent
  end

  # Call this method in a :after_initialize callback, passsing it
  # a list of attributes that are supposed to be serialized hash
  # with indifferent access; if they are, nothing happens. If they
  # happen to be ordinary hashes, they'll be upgraded.
  def ensure_serialized_hash_are_indifferent #:nodoc:
    to_update = {}
    ser_attinfo = self.class.serialized_attributes
    attlist = ser_attinfo.keys.select { |att| ser_attinfo[att] == BasicObject }
    #attlist = ser_attinfo.keys
    attlist.each do |att|
      the_hash = read_attribute(att) # value of serialized attribute, as reconstructed by ActiveRecord
      if the_hash.is_a?(Hash) && ! the_hash.is_a?(HashWithIndifferentAccess)
#puts_blue "Oh oh, must fix #{self.class.name}-#{self.id} -> #{att}"
        #new_hash = HashWithIndifferentAccess.new_from_hash_copying_default(the_hash)
        new_hash = the_hash.with_indifferent_access
        to_update[att] = new_hash
      end
    end

    unless to_update.empty?
      # Proper code that is supposed to update it once and for all in the DB:

      #self.update_attributes(to_update) # reactive once YAML dumping is fixed in Rails

      # Unfortunately, currently a HashWithIndifferentAccess is serialized EXACTLY as a Hash, so
      # it doesn't save any differently in the DB. To prevent unnecessary writes and rewrites of
      # always the same serialized Hash, we'll just update the attribute in memory instead:
      to_update.each do |att,val|
        write_attribute(att,val)
      end
    end

    true
  end

end



###################################################################
# CBRAIN Kernel extensions
###################################################################

module Kernel

  private

  # Raises a CbrainNotice exception, with a default redirect to
  # the current controller's index action.
  def cb_notify(message = "Something may have gone awry.", options = {} )
    options[:status]       ||= :ok
    options[:shift_caller]   = 2
    raise CbrainNotice.new(message, options)
  end
  alias cb_notice cb_notify

  # Raises a CbrainError exception, with a default redirect to
  # the current controller's index action.
  def cb_error(message = "Some error occured.",  options = {} )
    options[:status]       ||= :bad_request
    options[:shift_caller]   = 2
    raise CbrainError.new(message, options)
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_red(message)
    puts "\e[31m#{message}\e[0m"
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_green(message)
    puts "\e[32m#{message}\e[0m"
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_blue(message)
    puts "\e[34m#{message}\e[0m"
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_yellow(message)
    puts "\e[33m#{message}\e[0m"
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_magenta(message)
    puts "\e[35m#{message}\e[0m"
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_cyan(message)
    puts "\e[36m#{message}\e[0m"
  end
  
  def puts_timer(message, colour = nil, reset = false)
    @@__DEBUG_TIMER__ ||= nil
    if reset
      @@__DEBUG_TIMER__ = nil
    end
    if @@__DEBUG_TIMER__
      @@__DEBUG_TIMER__.timed_puts(message, colour)
    else
      @@__DEBUG_TIMER__ = DebugTimer.new
      method = "puts"
      if colour
        method = "puts_#{colour}"
      end
      send method, message
    end
  end

end



###################################################################
# CBRAIN Extensions To Core Types
###################################################################

class Symbol

  # Used by views for CbrainTasks to transform a
  # symbol such as :abc into a path to a variable
  # inside the params[] hash, as "cbrain_task[params][abc]".
  #
  # CBRAIN adds a similar method in the String class.
  def to_la
    "cbrain_task[params][#{self}]"
  end

  # Used by views for CbrainTasks to transform a
  # symbol such as :abc (representing a path to a
  # variable inside the params[] hash) into the name
  # of a pseudo accessor method for that variable.
  # This is also the name of the input field's HTML ID
  # attribute, used for error validations.
  #
  # CBRAIN adds a similar method in the String class.
  def to_la_id
    self.to_s.to_la_id
  end

end

class String

  # Used by views for CbrainTasks to transform a
  # string such as "abc" or "abc[def]" into a path to a
  # variable inside the params[] hash, as in
  # "cbrain_task[params][abc]" or "cbrain_task[params][abc][def]"
  #
  # CBRAIN adds a similar method in the Symbol class.
  def to_la
    key = self
    if key =~ /^(\w+)/
      newcomp = "[" + Regexp.last_match[1] + "]"
      key = key.sub(/^(\w+)/,newcomp) # not sub!() !
    end
    "cbrain_task[params]#{key}"
  end

  # Used by views for CbrainTasks to transform a
  # string such as "abc" or "abc[def]" (representing
  # a path to a variable inside the params[] hash, as in
  # "cbrain_task[params][abc]" or "cbrain_task[params][abc][def]")
  # into the name of a pseudo accessor method for that variable.
  # This is also the name of the input field's HTML ID
  # attribute, used for error validations.
  #
  # CBRAIN adds a similar method in the Symbol class.
  def to_la_id
    self.to_la.gsub(/\W+/,"_").sub(/_+$/,"").sub(/^_+/,"")
  end

  # Considers self as a pattern to which substitutions
  # are to be applied; the substitutions are found in
  # self by recognizing keywords surreounded by
  # '{}' (curly braces) and those keywords are looked
  # up in the +keywords+ hash.
  #
  # Example:
  #
  #  mypat  = "abc{def}-{mach-3}{ext}"
  #  mykeys = {  :def => 'XYZ', 'mach-3' => 'fast', :ext => '.zip' }
  #  mypat.pattern_substitute( mykeys ) # return "abcXYZ-fast.zip"
  #
  # Note that keywords are limited to sequences of lowercase
  # characters and digits, like 'def', '3', or 'def23' or the same with
  # a number extension, like '4-34', 'def-23' and 'def23-3'.
  #
  # Options:
  #
  # :allow_unset, if true, allows substitution of an empty
  # string if a keyword is defined in the pattern but not
  # in the +keywords+ hash. Otherwise, an exception is raised.
  # :leave_unset, if true, leaves unsubstituded keywords as-is
  # in the string.
  def pattern_substitute(keywords, options = {})
    pat_comps = self.split(/(\{(?:[a-z0-9_]+(?:-\d+)?)\})/i)
    final = []
    pat_comps.each_with_index do |comp,i|
      if i.even?
        final << comp
      else
        barecomp = comp.tr("{}","")
        val = keywords[barecomp.downcase] || keywords[barecomp.downcase.to_sym]
        if val.nil?
          cb_error "Cannot find value for keyword '{#{barecomp.downcase}}'." if options[:leave_unset].blank? && options[:allow_unset].blank?
          val = comp                                                         if options[:leave_unset].present?
        end
        final << val.to_s
      end
    end
    final.join
  end

end

class Array

  # Converts the array into a complex hash.
  # Runs the given block, passing it each of the
  # elements of the array; the block must return
  # a key that will be given to build a hash table.
  # The values of the hash table will be the list of
  # elements of the original array for which the block
  # returned the same key. The method returns the
  # final hash.
  #
  #   [0,1,2,3,4,5,6].hashed_partition { |n| n % 3 }
  #
  # will return
  #
  #   { 0 => [0,3,6], 1 => [1,4], 2 => [2,5] }
  def hashed_partition
    partitions = {}
    self.each do |elem|
       key = yield(elem)
       partitions[key] ||= []
       partitions[key] << elem
    end
    partitions
  end

  alias hashed_partitions hashed_partition
  
end


class Hash

  # This method allows you to perform a transformation
  # on all the keys of the hash; the keys are going to be passed
  # in turn to the block, and whatever the block returns
  # will be the new key. Example:
  #
  #   { "1" => "a", "2" => "b" }.convert_keys!(&:to_i)
  #
  #   returns
  #
  #   { 1 => "a", 2 => "b" }
  def convert_keys!
    self.keys.each do |key|
      self[yield(key)] = delete(key)
    end
    self
  end

  # Turns a hash table into a string suitable to be used
  # as HTML element attributes.
  #
  #   { "colspan" => 3, :style => "color: #ffffff", :x => '<>' }.to_html_attributes
  #
  # will return the string
  #
  #   'colspan="3" style="color: blue" x="&lt;&gt;"'
  def to_html_attributes
    self.inject("") do |result,attpair|
      attname   = attpair[0]
      attvalue  = attpair[1]
      result   += " " if result.present?
      result   += "#{attname}=\"#{ERB::Util.html_escape(attvalue)}\""
      result
    end
  end

end

