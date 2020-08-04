
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

require 'set'

# Model representing a CBRAIN user's Rails session. The currently logged in
# user's session object can be accessed using the cbrain_session method of
# ApplicationController (from SessionHelpers).
#
# Meant as a complement to the rails session hash, this model is mostly used
# to add additional reporting/monitoring logic, to cleanly support partial
# updates and to validate certain session attributes.
#
# The database backend is through the ActiveRecord model returned by
# the class method +session_model+ .
class CbrainSession

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Create a new CbrainSession object wrapping +session+ (a Rails session)
  # backed by +model+, an instance of CbrainSession.session_model (which is
  # expected to be an ActiveRecord record).
  def initialize(session_or_largeinfo)
    if session_or_largeinfo.is_a?(self.class.session_model)
      @model = session_or_largeinfo
      return
    end
    sid = session_or_largeinfo[:session_id].presence || self.class.random_session_id

    # Find an existing LargeSession object
    @model   = self.class.session_model.where(
                 :session_id => sid,
                 :active     => true,
               ).first

    # Otherwise, create a new LargeSession object
    # The user_id can be nil if the Rails session is not logged in.
    # If it's set, it means we're creating a new LargeSession object because a previous
    # one was deleted or inactivated.
    # The current object here may or may not be saved at the end of the
    # request (it will certainly not if the user_id is missing).
    @model ||= self.class.session_model.new(
                 :session_id => sid,
                 :active     => true,
                 :data       => {},
                 :user_id    => session_or_largeinfo[:user_id],
               )
  end

  # ActiveRecord model class for Rails session info
  def self.session_model
    LargeSessionInfo
  end

  # Internal CBRAIN session tracking keys. Invisible to the API and end-user,
  # these keys keep track of the user's connection information.
  def self.tracking_keys
    @tracking_keys ||= Set.new([
      :guessed_remote_host,
      :guessed_remote_ip,
      :raw_user_agent,
    ])
  end

  # Internal CBRAIN session authentication, security, tracking and monitoring
  # attribute keys. They are invisible to the API and end-user.
  def self.internal_keys
    @internal_keys ||= Set.new([
      :_csrf_token,
      :user_id,
    ] + self.tracking_keys.to_a)
  end

  # User this session belongs to, from the :user_id attribute
  def user
    @user = User.find_by_id(@model[:user_id]) unless
      @user && @user.id == @model[:user_id]
    @user
  end

  # Returns the token for API calls; right now we use the original Rails session ID obtained
  # at logging in.
  def cbrain_api_token
    @model.try(:session_id)
  end

  # Returns the user if the model data indicates
  # that it represents a valid, active session connected with +token+
  def user_for_cbrain_api(token)
    return nil unless @model && @model.active? && self.cbrain_api_token == token
    self.user
  end

  # Change the user ID in underlying model; only used when switching users.
  def user_id=(uid)
    return unless @model
    @model.user_id = uid
    @modified      = true
  end

  # The remote_resource_id attribute
  # is used to record which portal the user
  # originally connected from, to aid in navigation.
  def remote_resource_id
    self[:remote_resource_id]
  end

  # See the getter method.
  def remote_resource_id=(rr_id)
    self[:remote_resource_id] = rr_id
  end

  ###########################################
  # Hash-like interface to session attributes
  ###########################################

  # Delegate [] to @model.data
  def [](key) #:nodoc:
    @model.data[key]
  end

  # Delegate []= to @model.data[]=
  def []=(key, value) #:nodoc:
    @modified        = true
    @model.data[key] = value
  end

  # Delegate delete to @model.data.delete
  def delete(key) #:nodoc:
    @modified = true
    @model.data.delete(key)
  end

  # Update sessions attributes from the contents of +changes+. +changes+ is
  # expected to be either a +hash+ of attributes to update, a +mode+ and a
  # +hash+ (pair) or a list of those to be applied in order:
  #   apply_changes({ ... }) # Single hash
  #   apply_changes([:delete, { ... }]) # Pair
  #   apply_changes([{ ... }, { ... }]) # List of hashes
  #   apply_changes([[:append, { ... }], [:delete, { ... }]]) # List of pairs
  #
  # While similar to Hash's merge method, this method has a few key
  # differences:
  #
  # - Hashes in +hash+ and session attributes are recursively merged:
  #     cbrain_session # { :a => { :b => 1 } }
  #     apply_changes({ :a => { :c => 1 } })
  #     cbrain_session # { :a => { :b => 1, :c => 1 } }
  #
  # - nil values are automatically removed from hashes to avoid clutter. This
  #   cleanly allows removing keys from hashes:
  #     cbrain_session # { :a => { :b => 1 } }
  #     apply_changes({ :a => { :b => nil } })
  #     cbrain_session # { :a => {} }
  #
  # - apply_changes does not accept a block; session attributes are always
  #   overwritten by their new value in +hash+, if present.
  #
  # +mode+ determines what kind of update should be performed. The possible
  # +mode+s are:
  #
  # [:replace]
  #  Replace colliding values in session attributes from the ones in +hash+,
  #  regardless of their type (default mode).
  #
  # [:append]
  #  Replace colliding values, as in +:replace+, except when at least one of
  #  them is a collection (Array or Set), in which case the resulting value
  #  is the union of both collections (or the collection and the element).
  #
  # [:delete]
  #  Remove any non-colliding value present in +hash+ from session
  #  attributes, except for collections (Array or Set), from which the elements
  #  in +changes+ are subtracted.
  #
  # While oddly specified, this method is hopefully intuitive to use and allow
  # a wide range of operations from just an input hash and a mode switch.
  # For example:
  #   # Adding a key to the session
  #   cbrain_session # { :a => 1 }
  #   apply_changes({ :b => 2 })
  #   cbrain_session # { :a => 1, :b => 2 }
  #
  #   # Adding an element to an array in the session
  #   cbrain_session # { :a => { :c => [1] } }
  #   apply_changes([:append, { :a => { :c => [2] } }])
  #   cbrain_session # { :a => { :c => [1, 2] } }
  #
  #   # Removing keys from the session
  #   cbrain_session # { :a => { :c => 1, :d => 2 } }
  #   apply_changes([:delete, { :a => { :c => nil, :d => 2 } }])
  #   cbrain_session # { :a => {} }
  def apply_changes(changes)
    # At least one of +vars+ is one of +classes+
    any_of = lambda do |vars, classes|
      vars.any? { |v| classes.any? { |c| v.is_a?(c) } }
    end
    # Every element of +vars+ is one of +classes+
    all_of = lambda do |vars, classes|
      vars.all? { |v| classes.any? { |c| v.is_a?(c) } }
    end

    # Apply the changes +new+ to +base+ (respecting +mode+) recursively.
    apply = lambda do |base, new, mode|
      # Avoid adding new keys when merging in delete mode
      new.select! { |k,v| base.has_key?(k) } if mode == :delete

      # FIXME: Unlike regular Ruby hashes, Rails' HashWithIndifferentAccess
      # hash subclass does not support a collision-handling block/proc. To work
      # around this, HashWithIndifferentAccess objects are converted back into
      # regular hashes.
      base = base.to_hash if base.is_a?(HashWithIndifferentAccess)

      base.merge!(new) do |key, old, new|
        # Recursively merge hashes with the same key
        next apply.(old, new, mode) if old.is_a?(Hash) && new.is_a?(Hash)

        # Unless one of the values is a collection, the old value is replaced
        # by the new one (or nil, when deleting).
        next (mode == :delete ? nil : new) unless (
          all_of.([new, old], [Set, Array, NilClass]) &&
          any_of.([new, old], [Set, Array]) &&
          [:append, :delete].include?(mode)
        )

        # Ensure both values exist before trying to merge them
        old ||= new.class.new
        new ||= old.class.new
        new   = new.to_a if old.is_a?(Array)

        # Merge both collections
        case mode
        when :append then old + new
        when :delete then old - new
        end
      end

      # Clear out nil values to avoid cluttering
      base.reject! { |k,v| v.nil? }
      base
    end

    # Is +obj+ a symbol-hash pair? ([Symbol, Hash])
    is_pair = lambda do |obj|
      obj.is_a?(Array) &&
      obj.size == 2 &&
      obj.first.is_a?(Symbol) &&
      obj.last.is_a?(Hash)
    end

    # Push each changeset through the update lambda (removing internal_keys
    # beforehand).
    changes = [changes] if is_pair.(changes)
    changes = [[:replace, changes]] if changes.is_a?(Hash)
    changes.each do |mode, change|
      apply.(
        @model.data,
        change.reject { |k,v| self.class.internal_keys.include?(k) },
        mode || :replace
      )
    end
    @modified = changes.present?
  end

  # Clear out all session attributes bar those used for tracking (IP, host,
  # user agent, ...). Used when the user logs out.
  def clear
    @model.data.select! { |k,v| self.class.tracking_keys.include?(k) }
    @modified = true
  end

  # Convert all session attributes directly into a regular hash.
  def to_h
    @model.data.to_h
  end

  # Reporting/monitoring methods

  # Active/inactive state; used mainly to mark currently active (logged in)
  # users for reporting purposes, as the sessions records sometimes linger
  # after the user logs out.

  # Mark this session as active.
  def activate(user_id)
    return unless @model

    @model.user_id = user_id
    @model.active  = true
    @model.save!
  end

  # Mark this session as inactive.
  def deactivate
    return unless @model

    @model.active = false
    @model.save!
  end

  # Save model if modified in any way. If not,
  # update timestamp of model ONLY if it's older
  # than 1 minute.
  def touch_unless_recent
    return             unless @model.present?
    clean_model_for_api    if @model.data[:api]
    return @model.save     if @modified && @model.changed? # I hate having two parallel systems to track this
    return                 if @model.updated_at.blank? || @model.updated_at > 1.minute.ago
    return                 if @model.new_record? && @model.data.try(:size) == 0
    @model.touch
  end

  # When using the CBRAIN API, we don't save any state information for scopes
  def clean_model_for_api #:nodoc:
    @model.data.delete "scopes"
  end

  def mark_as_modified #:nodoc:
    @modified = true
  end

  # User model scope of currently (recently) active users.
  # (active and had activity since +since+).
  def self.active_users(since: 10.minutes.ago)
    sessions = session_model.quoted_table_name
    users    = User.quoted_table_name

    User
      .joins("INNER JOIN #{sessions} ON #{sessions}.user_id = #{users}.id")
      .where("#{sessions}.active = 1")
      .where(since ? ["#{sessions}.updated_at > ?", since] : {})
  end

  # Report (as a list of hashes) the +n+ most recently active users and their
  # IP address, host name and user agent.
  def self.recent_activity(n = 10)
    sessions = session_model.quoted_table_name
    users    = User.quoted_table_name

    session_model
      .joins("INNER JOIN #{users} ON #{users}.id = #{sessions}.user_id")
      .order("#{sessions}.updated_at DESC")
      .limit(n)
      .map do |session|
        data = (session.data || {}) rescue {}
        {
          :user           => User.find_by_id(session.user_id),
          :active         => session.active?,
          :last_access    => session.updated_at,
          :remote_ip      => data[:guessed_remote_ip],
          :remote_host    => data[:guessed_remote_host],
          :raw_user_agent => data[:raw_user_agent]
        }
      end
  end

  # Clean out spurious session entries; entries older than +since+ without
  # an attached user.
  def self.clean_sessions(since: 1.hour.ago)
    session_model
      .where(:active => false)
      .where('updated_at < ?', since)
      .destroy_all
  end

  # Purge all session entries older than +since+, no matter if there is an
  # attached user or not.
  def self.purge_sessions(since: 1.hour.ago)
    session_model
      .where('updated_at < ?', since)
      .delete_all
  end

  def self.count #:nodoc:
    session_model.count
  end

  # Deprecated/old API methods

  # Fetch session parameters specific to controller +controller+.
  # Marked as deprecated as session attributes are no longer necessarily bound
  # to a controller.
  def params_for(controller) #:nodoc:
    controller  = (@model.data[controller.to_sym] ||= {})
    controller['filter_hash'] ||= {}
    controller['sort_hash']   ||= {}
    controller
  end

  HEX_DIGITS = ('0'..'9').to_a + ('a'..'f').to_a #:nodoc:

  # When the connection is coming from a non-browser,
  # we generate a unique, one-time session ID.
  def self.random_session_id #:nodoc:
    (0..31).map { HEX_DIGITS[rand(16)] }.join
  end

end
