
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
# user's session object can be accessed using the current_session method of
# ApplicationController (from SessionHelpers).
#
# Meant as a wrapper around Rails session hash, this model is mostly used
# to add additional reporting/monitoring logic, to cleanly support partial
# updates and to validate certain session attributes.
#
# NOTE: This model is not database-backed
class CbrainSession

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Create a new CbrainSession object wrapping +session+ (a Rails session)
  # backed by +model+, an instance of CbrainSession.session_model (which is
  # expected to be an ActiveRecord record).
  def initialize(session, model = nil)
    @session = session
    @model   = model
  end

  # ActiveRecord model class for Rails sessions
  def self.session_model
    ActiveRecord::SessionStore::Session
  end

  # Internal CBRAIN session tracking keys. Invisible to the API and end-user,
  # these keys keep track of the user's connection information.
  def self.tracking_keys
    @tracking_keys ||= Set.new([
      :client_type,
      :guessed_remote_host,
      :guessed_remote_ip,
      :raw_user_agent,
      :return_to,
    ].map(&:to_s))
  end

  # Internal CBRAIN session authentication, security, tracking and monitoring
  # attribute keys. They are invisible to the API and end-user.
  def self.internal_keys
    @internal_keys ||= Set.new([
      :_csrf_token,
      :cbrain_toggle,
      :user_id,
    ].map(&:to_s) + self.tracking_keys.to_a)
  end

  # User this session belongs to, from the :user_id attribute
  def user
    @user = User.find_by_id(@session[:user_id]) unless
      @user && @user.id == @session[:user_id]
    @user
  end

  # Load +user+'s preferences (session attributes) in the session from the
  # user's meta storage.
  # If +user+ is not specified or nil, load_preferences will try to use the
  # user bound to the session, if available.
  def load_preferences(user = nil)
    user  = self.user unless user.is_a?(User)
    prefs = (user.meta[:preferences] || {})
      .map    { |k,v| [k.to_sym, v] }
      .to_h
      .reject { |k,v| self.class.internal_keys.include?(k) }

    @session.merge!(prefs)
  end

  # Save this session object's attributes as the +user+'s preferences in the
  # user's meta storage (opposite of load_preferences).
  # If +user+ is not specified or nil, save_preferences will try to use the
  # user bound to the session, if available.
  def save_preferences(user = nil)
    user  = self.user unless user.is_a?(User)
    prefs = @session
      .reject { |k,v| self.class.internal_keys.include?(k) }
      .cb_deep_clone

    user.meta[:preferences] = (user.meta[:preferences] || {}).merge(prefs)
  end

  # Hash-like interface to session attributes

  # Delegate [] to @session
  def [](key) #:nodoc:
    @session[key]
  end

  # Delegate []= to @session
  def []=(key, value) #:nodoc:
    @session[key] = value
  end

  # Update sessions attributes from the contents of +changes+. +changes+ is
  # expected to be either a +hash+ of attributes to update, a +mode+ and a
  # +hash+ (pair) or a list of those to be applied in order:
  #   apply_changes({ ... }) # Single hash
  #   apply_changes([:delete, { ... }]) # Pair
  #   apply_changes([{ ... }, { ... }]) # List of hashes
  #   apply_changes([[:append, { ... }], [:delete, { ... }]]) # List of pairs
  #
  # While similiar to Hash's merge method, this method has a few key
  # differences:
  #
  # - Hashes in +hash+ and session attributes are recursively merged:
  #     @session # { :a => { :b => 1 } }
  #     update({ :a => { :c => 1 } })
  #     @session # { :a => { :b => 1, :c => 1 } }
  #
  # - nil values are automatically removed from hashes to avoid clutter. This
  #   cleanly allows removing keys from hashes:
  #     @session # { :a => { :b => 1 } }
  #     update({ :a => { :b => nil } })
  #     @session # { :a => {} }
  #
  # - update does not accept a block; session attributes are always overwritten
  #   by their new value in +hash+, if present.
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
  #  in +changes+ are substracted.
  #
  # While oddly specified, this method is hopefully intuitive to use and allow
  # a wide range of operations from just an input hash and a mode switch.
  # For example:
  #   # Adding a key to the session
  #   @session # { :a => 1 }
  #   apply_changes({ :b => 2 })
  #   @session # { :a => 1, :b => 2 }
  #
  #   # Adding an element to an array in the session
  #   @session # { :a => { :c => [1] } }
  #   apply_changes([:append, { :a => { :c => [2] } }])
  #   @session # { :a => { :c => [1, 2] } }
  #
  #   # Removing keys from the session
  #   @session # { :a => { :c => 1, :d => 2 } }
  #   apply_changes([:delete, { :a => { :c => nil, :d => 2 } }])
  #   @session # { :a => {} }
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
        @session,
        change.reject { |k,v| self.class.internal_keys.include?(k) },
        mode || :replace
      )
    end
  end

  # Clear out all session attributes bar those used for tracking (IP, host,
  # user agent, ...). Used when the user logs out.
  def clear
    @session.select! { |k,v| self.class.tracking_keys.include?(k) }
  end

  # Convert all session attributes directly into a regular hash.
  def to_h
    @session.to_h
  end

  # Reporting/monitoring methods

  # Active/inactive state; used mainly to mark currently active (logged in)
  # users for reporting purposes, as the sessions records sometimes linger
  # after the user logs out.

  # Mark this session as active.
  def activate
    return unless @model

    @model.user_id = @session[:user_id]
    @model.active  = true
    @model.save!
  end

  # Mark this session as inactive.
  def deactivate
    return unless @model

    @model.active = false
    @model.save!
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
          :remote_ip      => data['guessed_remote_ip'],
          :remote_host    => data['guessed_remote_host'],
          :raw_user_agent => data['raw_user_agent']
        }
      end
  end

  # Clean out spurious session entries; entries older than +since+ without
  # an attached user.
  def self.clean_sessions(since: 1.hour.ago)
    session_model
      .where('user_id IS NULL')
      .where('updated_at < ?', since)
      .destroy_all
  end

  # Purge all session entries older than +since+, no matter if theres an
  # attached user or not.
  def self.purge_sessions(since: 1.hour.ago)
    session_model
      .where('updated_at < ?', since)
      .delete_all
  end

  # Delegate other calls on CbrainSession to session_model, making CbrainSession
  # behave like Rails's session model.
  def self.method_missing(method, *args) # :nodoc:
    session_model.send(method, *args)
  end

  # Deprecated/old API methods

  # Fetch session parameters specific to controller +controller+.
  # Marked as deprecated as session attributes are no longer necessarily bound
  # to a controller.
  def params_for(controller) #:nodoc:
    controller  = (@session[controller.to_sym] ||= {})
    controller['filter_hash'] ||= {}
    controller['sort_hash']   ||= {}
    controller
  end

end
