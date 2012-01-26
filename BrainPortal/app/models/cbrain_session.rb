
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

#Model represeting the current session. The current session object can 
#be accessed using the <b><tt>current_session</tt></b> method of the ApplicationController
#class.
#
#This model is meant to act as a wrapper around the session hash.
#It takes care of updating the values of and performing any logic related 
#to the following attributes of the current session (mainly related
#to the Userfile index page):
#* currently active filters.
#* whether or not pagination is active.
#* current ordering of the Userfile index.
#* whether to view current user's files or all files on the system (*admin* only).
#
#Session attributes can be accessed by calling methods with the attribute name.
#*Example*: calling +current_session+.+current_filters+ will access <tt>session[:current_filters]</tt>
#
#*Note*: this is not a database-backed model.
class CbrainSession

  Revision_info=CbrainFileRevision[__FILE__]
  
  def initialize(session, params, sess_model) #:nodoc:
    @session       = session # rails session
    @session_model = sess_model # active record model that stores the session
    
    @session[:persistent_userfile_ids] ||= {}

    controller = params[:controller]
    @session[controller.to_sym] ||= {}
    @session[controller.to_sym]["filter_hash"] ||= {}
    @session[controller.to_sym]["sort_hash"] ||= {}
  end
  
  #Mark this session as active in the database.
  def activate
    @session_model.update_attributes!(:user_id => @session[:user_id], :active => true)
  end
  
  #Mark this session as inactive in the database.
  def deactivate
    @session_model.update_attributes!(:active => false)
  end
  
  #Returns the list of currently active users on the system.
  def self.active_users(options = {})
    active_sessions = session_class.where(
      ["sessions.active = TRUE AND sessions.user_id IS NOT NULL AND sessions.updated_at > ?", 10.minutes.ago]
    )
    user_ids = active_sessions.map(&:user_id).uniq
    scope = User.where(options)
    scope.where( :id => user_ids )
  end
  
  def self.count(options = {}) #:nodoc:
    scope = session_class.where(options)
    scope.count
  end
  
  def self.session_class #:nodoc:
     ActiveRecord::SessionStore::Session
  end

  def self.all #:nodoc:
    self.session_class.all
  end
  
  def self.recent_activity(n = 10, options = {}) #:nodoc:
    last_sessions = session_class.where( "sessions.user_id IS NOT NULL" ).order("sessions.updated_at DESC")
    entries = []
    
    last_sessions.each do |sess|
      break if entries.size >= n
      next  if sess.user_id.blank?
      user = User.find_by_id(sess.user_id)
      next unless user
      sessdata = (sess.data || {}) rescue {}
      entries << {
        :user           => user,
        :active         => sess.active?,
        :last_access    => sess.updated_at,
        :remote_ip      => sessdata["guessed_remote_ip"],    # can be nil, must be fecthed with string not symbol
        :remote_host    => sessdata["guessed_remote_host"],  # can be nil, must be fecthed with string not symbol
        :raw_user_agent => sessdata["raw_user_agent"],       # can be nil, must be fecthed with string not symbol
      }
    end
    
    entries
  end

  # Erase most of the entries in the data
  # section of the session; this is used when the
  # user logs out. Some elements are kept
  # for tracking no matter what, like the
  # :guessed_remote_host and the :raw_user_agent
  def clear_data!
    @session.each do |k,v|
      next if k.to_s =~ /guessed_remote_ip|guessed_remote_host|raw_user_agent/
      @session.delete(k)
    end
  end
  
  #Update attributes of the session object based on the incoming request parameters
  #contained in the +params+ hash.
  def update(params)
    controller = params[:controller]
    if params[controller]
      params[controller].each do |k, v|
        if @session[controller.to_sym][k].nil?
          if k =~ /_hash/
            @session[controller.to_sym][k] = {}
          elsif k =~ /_array/
            @session[controller.to_sym][k] = []
          end
        end
        if k == "remove" && v.is_a?(Hash)
          v.each do |list, item|
            if @session[controller.to_sym][list].respond_to? :delete
              @session[controller.to_sym][list].delete item
            else
              @session[controller.to_sym].delete list
            end
          end
        elsif k =~ /^clear_(.+)/
          pattern = Regexp.last_match[1].gsub(/\W/, "")
          if pattern == "all"
            clear_list = v
            clear_list = [v] unless v.is_a? Array
          else
            clear_list = @session[controller.to_sym].keys.grep(/^#{pattern}/)
          end
          clear_list.each do |item|
            if item == "all"
              @session[controller.to_sym].clear
              @session[controller.to_sym]["filter_hash"] ||= {}
              @session[controller.to_sym]["sort_hash"] ||= {}
            elsif @session[controller.to_sym][item].respond_to? :clear
              @session[controller.to_sym][item].clear
            else
              @session[controller.to_sym].delete item
            end
          end
        else
          if @session[controller.to_sym][k].is_a? Hash
            params[controller][k].delete_if { |pk, pv| pv.blank?   }
            @session[controller.to_sym][k].merge!(sanitize_params(k, params[controller][k]) || {})
          elsif @session[controller.to_sym][k].is_a? Array
            sanitized_param = sanitize_params(k, params[controller][k])
            @session[controller.to_sym][k] |= [sanitized_param] if sanitized_param
          else
            @session[controller.to_sym][k] = sanitize_params(k, params[controller][k])
          end
        end
      end
    end
  end
  
  #Returns the params saved for +controller+.
  def params_for(controller)
    @session[controller.to_sym]
  end
  
  #Hash-like access to session attributes.
  def [](key)
    @session[key]
  end
  
  #Hash-like assignment to session attributes.
  def []=(key, value)
    if key == :user_id
      @session_model.update_attributes!(:user_id => value)
    end
    @session[key] = value
  end
  
  #The method_missing method has been redefined to allow for simplified access to session parameters.
  #
  #*Example*: calling +current_session+.+current_filters+ will access <tt>session[:current_filters]</tt>
  def method_missing(key, *args)
    @session[key.to_sym]
  end

  ###########################################
  # Peristent Userfile Ids Management Methods
  ###########################################

  # Clear the list of persistent userfile IDs;
  # returns the number of userfiles that were there.
  def persistent_userfile_ids_clear
    persistent_ids = self[:persistent_userfile_ids] ||= {}
    original_count = persistent_ids.size
    self[:persistent_userfile_ids] = {}
    original_count
  end

  # Add the IDs in the array +id_list+ to the
  # list of persistent userfile IDs.
  # Returns the number of IDs that were actually added.
  def persistent_userfile_ids_add(id_list)
    added_count    = 0
    persistent_ids = self[:persistent_userfile_ids] ||= {}
    id_list.each do |id|
      next if persistent_ids[id]
      persistent_ids[id] = true
      added_count += 1
    end
    added_count
  end

  # Removed the IDs in the array +id_list+ to the
  # list of persistent userfile IDs.
  # Returns the number of IDs that were actually removed.
  def persistent_userfile_ids_remove(id_list)
    removed_count  = 0
    persistent_ids = self[:persistent_userfile_ids] ||= {}
    id_list.each do |id|
      next unless persistent_ids[id]
      persistent_ids.delete(id)
      removed_count += 1
    end
    removed_count
  end

  # Returns an array of the list of persistent userfile IDs.
  def persistent_userfile_ids_list
    persistent_ids = self[:persistent_userfile_ids] ||= {}
    persistent_ids.keys
  end

  # Returns the persistent userfile IDs as a hash.
  def persistent_userfile_ids
    persistent_ids = self[:persistent_userfile_ids] ||= {}
    persistent_ids
  end

  private
  
  def sanitize_params(k, param) #:nodoc:
    key = k.to_sym
    
    if key == :sort_hash
      param["order"] = sanitize_sort_order(param["order"])
      param["dir"] = sanitize_sort_dir(param["dir"])
    end
    
    param
  end
  
  def sanitize_sort_order(order) #:nodoc:
    table, column = order.strip.split(".")
    table = table.tableize
    
    unless ActiveRecord::Base.connection.tables.include?(table)
      cb_error "Invalid sort table: #{table}."
    end
    
    klass = Class.const_get table.classify
    
    unless klass.column_names.include?(column) ||
        (klass.respond_to?(:pseudo_sort_columns) && klass.pseudo_sort_columns.include?(column))
      cb_error "Invalid sort column: #{table}.#{column}"
    end
    
    "#{table}.#{column}"
  end
  
  def sanitize_sort_dir(dir) #:nodoc:
    if dir.to_s.strip.upcase == "DESC"
      "DESC"
    else
      ""
    end
  end
  
end
