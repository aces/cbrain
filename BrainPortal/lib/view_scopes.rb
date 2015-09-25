
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

# Helpers to apply user-specified scopes on CBRAIN's models or collections for
# viewing purposes. Scopes are a flexible and safe way to define which filtering
# and sorting rules to apply on a given collection before display and keep 
# track of item selection and pagination information.
#
# Scopes currently in use are usually stored in Rails' session, and can easily
# be converted to and from hashes. For example, a scope to filter by an
# attribute named user_id and sort by name would look like:
#   scope = Scope.from_hash({
#     :filters => [
#       {
#         :attribute => :user_id,
#         :value     => 10,
#       },
#     ],
#     :order => [
#       {
#         :attribute => :name,
#         :direction => :asc,
#       },
#     ]
#   })
# To then apply this scope to a collection or model, use the scope's apply
# method:
#   scoped_tools = scope.apply(Tool)
#
# Currently active/known scopes are stored in Rails' session as a hash with
# scope names for keys and scope hash definitions/representations as values:
#   current_session['scopes'] == {
#     'userfiles' => { 'f' => [ ... ], 'o' => ... },
#     'tasks'     => { 'f' => [ ... ], 'o' => ... },
#     ...
#   }
# To directly add or replace one of the session scopes, convert the scope to a
# compact hash representation first before adding to
# +current_session['scopes']+:
#   current_session['scopes']['tasks'] = scope.to_hash(compact: true)
#
# Scopes created from hashes and session attributes are automatically sanitized
# and it is thus safe to pass user-supplied values to create them.
# Note that scopes stored in Rails' session are in compact hash representation,
# see +Scope+'s +compact_hash+ method for more information.
#
# NOTE: While similar to ActiveRecord's scoping mechanism, the scopes defined in
# this module mainly target views, by taking concerns such as selection and
# pagination, and are expected to be 'closer' to the user than ActiveRecord's
# scopes (which would pose a security risk if they could be directly accessed).
module ViewScopes

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # ViewScopes is intended to be included as a controller extension module,
  # exposing +scope_from_session+, +scope_to_session+ and +default_scope_name+.
  def self.included(includer) #:nodoc:
    includer.class_eval do
      helper_method(
        :default_scope_name,
        :scope_from_session,
        :scope_to_session
      )

      before_filter(:update_session_scopes)
    end
  end

  # Represents a scope to filter and sort a given model or collection
  # (via +apply+) and hold selection and pagination information. This object is
  # typically created from an hash representation (see +from_hash+ and
  # +scope_from_session+).
  class Scope

    # Name of this scope in Rails' session. This attribute is transient, not
    # present in any hash representation and is only used to keep track of
    # which session scope hash representation it was generated from. It notably
    # allows keeping track of the active session scope in a controller without
    # having to carry the name around.
    #
    # Note that this attribute is entirely optional and does not influence the
    # operation of Scope's methods in any way.
    attr_accessor :name

    # Filters this scope filters the collection or model with. Instances of
    # Scope::Filter, each represents a single filtering rule to apply.
    #
    # While filters will be applied in order, filters are expected to be
    # independent from eachother and should thus given the same result no
    # matter in which order they are applied.
    attr_accessor :filters

    # Set operation to combine the filter result sets with. Either +and+ or
    # +intersection+ for intersection (each item in the final result set must
    # match all filters) or +or+ or +union+ for union (each item in the final
    # result set must match at least one filter).
    #
    # TODO: Not implemented yet, as +or+/+union+ is not implemented for
    # ActiveRecord models (the query interface does not support them cleanly
    # as of Rails 3) and slow/awkward for regular Ruby collections.
    attr_accessor :filter_combination

    # Ordering/sorting rules to sort the collection or model with. Instances of
    # Scope::Order, each represents a part of the ordering to apply; each rule
    # is applied in order, and rules beyond the first one sort elements that
    # were considered equal under the first rule (just like SQL's ORDER BY
    # clause).
    #
    # TODO: 'ORDER BY'-like behavior is not yet implemented for Ruby
    # collections; only the first Scope::Order instance will be applied to the
    # collection/model.
    attr_accessor :order

    # Pagination component to paginate (split into pages of fixed size) the
    # collection or model with, if required. Instance of Scope::Pagination.
    #
    # While a UI concern somewhat detached from sorting and filtering,
    # pagination is a key UI concept which needs to be applied to the
    # collection or model before it can be displayed (and thus belongs in Scope)
    attr_accessor :pagination

    # List of record IDs (models) and collection keys (or indices, if there is
    # no such thing) selected by the user in the model or collection.
    #
    # While a UI concern, keeping selection in scopes allows any component of
    # the application to access and alter user selection and allows persisting
    # selection information with scopes in the session or DB.
    attr_accessor :selection

    # An indifferent hash of extra scoping/filtering/sorting parameters specific
    # to the Scope instance. These extra parameters can be used to store extra
    # view-specific options that would otherwise have to be persisted and set
    # manually.
    attr_accessor :custom

    # Create a new blank Scope without any filtering or sorting rules. Once
    # the filter has been created, rules can be subsequently added using the
    # filters and order attributes.
    #
    # To create a scope already initialized with a set of rules, see the
    # +from_hash+ class method.
    def initialize
      @filters   = []
      @order     = []
      @selection = []
      @custom    = HashWithIndifferentAccess.new
    end

    # Create a deep copy of the Scope +other+, down to each Filter in *filters*
    # and each Order in *order*. This method allows +dup+ and +clone+ (which
    # invoke it) to create independent copies which can then be used by
    # +scope_params+ and +url_for+ to create URLs changing arbitrary Scope
    # elements (see +scope_params+).
    def initialize_copy(other)
      hash_dup = lambda { |obj| obj.class.from_hash(obj.to_hash) }

      @filters    = other.filters.map(&hash_dup)
      @order      = other.order.map(&hash_dup)
      @pagination = hash_dup.(other.pagination) if other.pagination
      @selection  = other.selection.dup
      @custom     = other.custom.dup
    end

    # Apply the set of filtering and sorting rules from this scope to a given
    # +collection+, which is either an ActiveRecord model or a Ruby Enumerable.
    # Once the rules have been applied, the original collection is returned,
    # scoped with the scope's rules; a scoped ActiveRecord model if +collection+
    # was a model or a new Ruby Enumerable matching the rules if +collection+
    # was a Ruby Enumerable.
    #
    # If a rule application fails (a filter's target attribute does not exist on
    # +collection+, for example), +on_failure+ specifies how to handle the
    # failure. Three failure resolution methods are available:
    # [:ignore] The erroneous rule is skipped (default).
    # [:empty]  An empty collection is returned.
    # [:raise]  The erroneous rule's raised exception is re-thrown/re-raised.
    # This parameter is mainly used to avoid raising filtering/sorting rule
    # exceptions to callers which might just want to ignore the erroneous filter
    # rather than directly handling the issue (as Scopes are mainly used for
    # views).
    #
    # Note that pagination is not applied by default; specify +paginate+ to
    # paginate +collection+.
    def apply(collection, on_failure: :ignore, paginate: false)
      # Wrap a filtering or sorting rule application to handle exceptions,
      # using +fallback+ as a fall-back value for :ignore.
      empty = (collection <= ActiveRecord::Base rescue nil) ?
        collection.where('1 = 0') : []
      wrap = lambda do |fallback, &block|
        begin
          block.call()
        rescue => e
          case on_failure
          when :ignore then next fallback
          when :empty  then return empty
          when :raise  then raise
          end
        end
      end

      # Apply all filtering rules
      collection = @filters.inject(collection) do |collection, filter|
        wrap.(collection) { filter.apply(collection) }
      end

      # Apply sorting rules
      if (collection <= ActiveRecord::Base rescue nil)
        collection = @order.inject(collection) do |collection, order|
          wrap.(collection) { order.apply(collection) }
        end
      else
        collection = wrap.(collection) { @order.first.apply(collection) } unless
          @order.empty?
      end

      # Paginate
      collection = wrap.(collection) { @pagination.apply(collection) } if
        paginate && @pagination

      collection
    end

    # Create a new Scope described by the contents of +hash+. Each recognized
    # pair in +hash+ corresponds to a Scope attribute and is expected to
    # match the format of the attribute (e.g. +filters+ should be an Enumerable
    # of filters).
    #
    # For attributes containing objects (*filters*, *order*, *pagination*, etc.)
    # of which the class implements a +from_hash+ method, a hash is also
    # accepted instead of an instance; the instance will be created using the
    # method and the provided hash:
    #   some_filter_hash = { ... }
    #   Scope.from_hash({
    #     :filters => [ some_filter_hash ]
    #   })
    # corresponds to:
    #   some_filter_hash = { ... }
    #   filter = Scope::Filter.from_hash(some_filter_hash)
    #   Scope.from_hash({
    #     :filters => [ filter ]
    #   })
    #
    # The following keys are recognized in +hash+:
    #
    # [+filters+ or +f+]
    #  *filters* attribute: an array (or Enumerable) of Scope::Filter instances.
    #
    # [+order+ or +o+]
    #  *order* attribute: an array (or Enumerable) of Scope::Order instances.
    #
    # [+pagination+ or +p+]
    #  *pagination* attribute: a Scope::Pagination instance.
    #
    # [+selection+ or +s+]
    #  *selection* attribute: an array of selected IDs or keys inside the
    #  collection.
    #
    # [+custom+ or +c+]
    #  *custom* attribute: an arbitrary Ruby hash of custom view options.
    #
    # [+filter_combination+ or +fc+]
    #  *filter_combination* attribute: either +and+/+intersection+ or
    #  +or+/+union+ (defaults to +and+).
    #
    # Any missing key will lead to a nil attribute and be handled accordingly;
    # arrays will default to empty and absent components will be ignored.
    #
    # Returns the newly created Scope (just like new would)
    def self.from_hash(hash)
      # Make sure +hash+ is proper
      return nil unless hash.is_a?(Hash)

      hash = hash.with_indifferent_access unless
        hash.is_a?(HashWithIndifferentAccess)

      scope = self.new

      # Filtering and ordering rules
      scope.filters = (hash['filters'] || hash['f'] || [])
        .map { |filter| Filter.from_hash(filter) }
        .compact

      scope.order = (hash['order'] || hash['o'] || [])
        .map { |order| Order.from_hash(order) }
        .compact

      # Pagination, selection and other properties
      scope.pagination = Pagination.from_hash(hash['pagination'] || hash['p'])
      scope.selection  =  hash['selection'] || hash['s'] || []
      scope.custom     = (hash['custom']    || hash['c'] || {}).with_indifferent_access
      scope.filter_combination = (hash['filter_combination'] || hash['fc'] || 'and').to_s

      scope
    end

    # Convert this Scope into a hash, doing the exact opposite of +from_hash+
    # and converting as many object attributes into hashes (using their own
    # +to_hash+ methods) as possible. The generated hash will have the same
    # structure as what +from_hash+ accepts. Specifying +compact+ will have
    # +to_hash+ compact the generated hash just like +compact_hash+ would (see
    # +compact_hash+).
    def to_hash(compact: false)
      hash = {
        'filters'    => @filters.map(&:to_hash),
        'order'      => @order.map(&:to_hash),
        'pagination' => @pagination.try(:to_hash),
        'selection'  => @selection,
        'custom'     => @custom.stringify_keys.to_h,
        'filter_combination' => @filter_combination.to_s,
      }

      compact ? self.class.compact_hash(hash) : hash
    end

    # Compact +hash+, which is expected to be a Ruby hash matching +from_hash+'s
    # structure, to try and make +hash+ as compact/small as possible while
    # respecting +from_hash+'s structure by using the short key versions and
    # omitting blank/default fields.
    def self.compact_hash(hash)
      # Make sure +hash+ is proper
      return nil unless hash.is_a?(Hash)

      hash = hash.with_indifferent_access unless
        hash.is_a?(HashWithIndifferentAccess)

      compact = {
        # Compact filtering rules
        'f' => (hash['filters'] || hash['f'] || [])
          .map { |filter| Filter.compact_hash(filter) }
          .reject(&:blank?),

        # Compact ordering rules
        'o' => (hash['order'] || hash['o'] || [])
          .map { |order| Order.compact_hash(order) }
          .reject(&:blank?),

        # Compact the pagination component
        'p' => Pagination.compact_hash(hash['pagination'] || hash['p']),

        # Include other attributes
        's'  =>  hash['s']  || hash['selection'],
        'c'  => (hash['c']  || hash['custom'] || {}).stringify_keys.to_h,
        'fc' => (hash['fc'] || hash['filter_combination']).to_s,
      }

      # Delete empty/default values
      compact.delete_if { |key, value| value.blank? }
      compact.delete('fc') if compact['fc'].to_s == 'and'

      compact
    end

    # Represents a single filtering rule to apply on an ActiveRecord model or
    # Ruby collection (Enumerable).
    #
    # This class covers the following filtering clauses:
    # - Direct comparison using operators; ==, !=, >, >=, <, <= and 'like' for
    #   strings.
    # - Set inclusion/exclusion (x in [a, b, c, d])
    # - Range matching (between x and y)
    # - Association filtering for ActiveRecord models
    #
    # This class is also intended to be used as a base class for more
    # specialized filtering cases. To subclass Filter, the following methods
    # will most likely need to be re-implemented in the subclass to match the
    # specialized filter's needs, as their behavior is specific to this generic
    # filter:
    # - +self.type_name+
    # - +apply+
    # - +valid?+
    # - +self.from_hash+
    # - +to_hash+
    # - +self.compact_hash+
    # Note that subclasses need to make sure their generated hash
    # representations have the correct +type+ (+t+) key, or +from_hash+ wont
    # be able to recreate the right object.
    class Filter
      # Name of the collection/model attribute to filter on, as a string or
      # symbol. Must be present as an attribute in collection/model elements or
      # the filter will be ignored.
      #
      # Note that it can also be an attribute on the matching association
      # element if an association is specified.
      attr_accessor :attribute

      # Value(s) to filter against. Either a single value (direct comparison),
      # a set of values (set inclusion/exclusion) or a pair of values (range
      # matching), depending on which kind of filtering is to be done.
      attr_accessor :value

      # Predicate operator to apply to *attribute*'s value and *value* to
      # check if the collection/model element passes the filter. The possible
      # operators are:
      #
      # [+==+, +!=+, +>+, +>=+, +<+, +<=+]
      #  Standard comparison operators; a single value in *value* is expected.
      #
      # [+in+, +out+]
      #  Set inclusion (in) or exclusion (out); a set (Enumerable) of values
      #  in *value* is expected.
      #  Behaves like Ruby's include? method and SQL's IN clause.
      #
      # [+match+]
      #  Case insensitive string inclusion; a single string in *value* is
      #  expected.
      #  Behaves like a case-insensitive Ruby include? and SQL's LIKE clause.
      #  Shortened to just +m+ in compact Filter hash representations.
      #
      # [+range+]
      #  Range match; a pair of values in *value* is expected.
      #  Given a range [a, b] in *value* and x as *attribute*'s value,
      #  corresponds to the predicate a <= x <= b.
      #  Shortened to just +r+ in compact Filter hash representations.
      #
      # Defaults to an equality comparison (+==+).
      attr_accessor :operator

      # Optional ActiveRecord model to join on to the filtered model before
      # filtering, to allow for *attribute* to refer to attributes on the
      # joined model.
      #
      # By default, a regular Rails join will be used to join the two models.
      # To specify join columns, make *association* an array with three
      # elements; the association model, the association model's join attribute
      # and the original model's join attribute. For example, to join the Users
      # model to the Userfiles model via the *owner* attribute:
      #   # Userfiles has :owner, Users has :id
      #   [ :userfiles, :owner, :id ]
      #
      # To avoid any ambiguity between the two models for which model
      # *attribute* refers to, *attribute* can be prefixed with the association
      # name: +'userfiles.name'+ (or +:'userfiles.name'+).
      #
      # Only meaningful when filtering ActiveRecord models.
      attr_accessor :association

      # Short type name for this type of specialized filter.
      # This method is expected to be implemented in Scope::Filter subclasses
      # to determine which Filter subclass to load when creating a Filter
      # instance using +from_hash+.
      # Returns nil in the superclass (Scope::Filter) as a filter hash is
      # assumed to be a Scope::Filter if no +type+ key is present
      # (see +from_hash+).
      def self.type_name
        nil
      end

      # Filter the given +collection+ (an ActiveRecord model or a Ruby
      # Enumerable) according to the filtering predicate defined by this
      # object's attributes (see each attribute's documentation for how they
      # influence filtering).
      # Returns a filtered subset of +collection+.
      #
      # Note that if the filter is not valid (no *operator* or *attribute*),
      # an exception will be thrown.
      def apply(collection)
        raise "no operator to filter with"      unless @operator
        raise "no attribute to filter on items" unless @attribute

        @value ||= [] if [ 'in', 'out', 'range' ].include?(@operator.to_s)

        if (collection <= ActiveRecord::Base rescue nil)
          apply_on_model(collection)
        else
          apply_on_collection(collection)
        end
      end

      # Check if this Filter object is valid and able to filter a collection or
      # model; a Filter is valid if it has an *operator* and *attribute*.
      def valid?
        return @operator && @attribute
      end

      # Create a new Filter described by the contents of +hash+. Just like
      # Scope's +from_hash+ method, each recognized pair in +hash+ corresponds
      # to a Filter attribute (except for type, see below) and is expected to
      # match the attribute's format.
      #
      # The following keys are recognized in +hash+:
      #
      # [+type+ or +t+]
      #  Type (subclass) of Filter of create from +hash+, as a string or symbol.
      #  If present, this key's value is expected to match a subclass'
      #  +type_name+ (or the Ruby class name) and that subclass' +from_hash+
      #  will be invoked on +hash+ to create the filter instead. If the key does
      #  not match any subclass' +type_name+, a blank filter will be created.
      #
      # [+attribute+ or +a+]
      #  *attribute* attribute: a symbol or string.
      #
      # [+value+ or +v+]
      #  *value* attribute: a scalar (number, bool, string, symbol, etc.)
      #  value or an array (or Enumerable) of scalar values.
      #
      # [+operator+ or +o+]
      #  *operator* attribute: one of the possible operators (see the
      #  *operator* attribute) as a symbol or string (defaults to ==).
      #
      # [+association+ or +j+]
      #  *association* attribute: an ActiveRecord model or an array with an
      #  ActiveRecord model and the two attributes to perform the join with.
      #  A string or symbol representing the model or DB table can also be
      #  supplied instead of the model itself; +from_hash+ will resolve them
      #  to the actual model.
      #
      # Returns the newly created Filter (just like new would)
      def self.from_hash(hash)
        # Make sure +hash+ is proper
        return nil unless hash.is_a?(Hash)

        hash = hash.with_indifferent_access unless
          hash.is_a?(HashWithIndifferentAccess)

        filter = self.new

        # Handle Filter subclasses (type key)
        if type = (hash['type'] || hash['t'])
          subclass = self.descendants.find { |sub| sub.type_name == type }
          return subclass && subclass.respond_to?(:from_hash) ?
            subclass.from_hash(hash) : filter
        end

        # *attribute* must be alphanumeric (word-like)
        attribute = (hash['attribute'] || hash['a']).to_s.gsub(/[^\w.]/, '')
        filter.attribute = attribute unless attribute.blank?

        # *operator* must be one of the possible predicate operators
        possible_operators = [
          '==', '!=', '>', '>=', '<', '<=',
          'in', 'out', 'match', 'range'
        ]

        operator = (hash['operator'] || hash['o'] || :==).to_s.downcase
        operator = 'range' if operator == 'r'
        operator = 'match' if operator == 'm'
        filter.operator = operator if possible_operators.include?(operator)

        # *value* must be a simple scalar value or a set of simple values,
        # depending on which *operator* is to be applied
        scalars = [
          Numeric,
          String, Symbol,
          Date, DateTime,
          TrueClass, FalseClass,
          NilClass
        ]

        value = hash['value'] || hash['v']
        value = (value.is_a?(Enumerable) ? value : [value]).select do |v|
          scalars.any? { |c| v.is_a?(c) }
        end

        filter.value = (
          case operator.to_s
          when '==', '!=', '>', '>=', '<', '<='
            value.first
          when 'in', 'out'
            value unless value.empty?
          when 'match'
            value.first.to_s
          when 'range'
            value[0, 2] if value.length == 2
          else
            nil
          end
        )

        # *association* must be an ActiveRecord model or an array with the
        # correct format
        filter.association = ViewScopes.parse_assoc(hash['association'] || hash['j'])

        filter
      end

      # Convert this Filter into a hash, doing the exact opposite of
      # +from_hash+. This method behaves almost identically to Scope's +to_hash+
      # method (and has the same argument +compact+), except for being applied
      # to a Filter object instead of a Scope.
      # Note that the *association* attribute will be represented as the name
      # of its corresponding DB table in the generated hash.
      #
      # See Scope's +to_hash+ method for further information.
      def to_hash(compact: false)
        hash = {
          'attribute'   => @attribute.to_s,
          'operator'    => @operator.to_s,
          'value'       => @value,
          'association' => ViewScopes.assoc_with_table(@association)
        }

        compact ? self.class.compact_hash(hash) : hash
      end

      # Compact +hash+, which is expected to be a Ruby hash matching
      # +from_hash+'s structure. Behaves similarly to Scope's +compact_hash+
      # method, except for being applied to a Filter hash representation
      # instead of a Scope one.
      #
      # Note that if +hash+ contains a +type+ (or +t+) key and a valid subclass
      # exists, this method will invoke the subclass' own +compact_hash+ (if it
      # exists) to compact +hash+.
      def self.compact_hash(hash)
        return nil unless hash.is_a?(Hash)

        # Handle Filter subclasses (type key)
        if type = (hash['type'] || hash[:type] || hash['t'] || hash[:t])
          subclass = self.descendants.find { |sub| sub.type_name == type }
          return subclass.compact_hash(hash) if
            subclass && subclass.respond_to?(:compact_hash)
        end

        Scope.generic_compact_hash(
          hash,
          {
            'type'        => 't',
            'attribute'   => 'a',
            'operator'    => 'o',
            'value'       => 'v',
            'association' => 'j'
          },
          values: [
            [ 'operator', 'range', 'r' ],
            [ 'operator', 'match', 'm' ]
          ],
          defaults: { 'operator' => '==' }
        )
      end

      private

      # Filter the given +model+, an ActiveRecord model.
      # Internal model-specific implementation of the +apply+ method; see
      # +apply+ for more information on this method.
      def apply_on_model(model) #:nodoc:
        # Resolve and validate *attribute* as an attribute of +model+ (or
        # *association*).
        attribute, model = ViewScopes.resolve_model_attribute(@attribute, model, @association)

        case (operator = @operator.to_s)
        # Standard comparison operators can just be used as-is, bar for == and
        # when NULLs are involved.
        when '==', '!=', '>', '>=', '<', '<='
          sql_operator = (
            # IS/IS NOT for NULLs (nil)
            if    @value.nil? && operator == '==' then 'IS'
            elsif @value.nil? && operator == '!=' then 'IS NOT'
            # SQL uses a single =
            elsif operator == '==' then '='
            # Other cases are as-is
            else operator
            end
          )
          return model.where("#{attribute} #{sql_operator} ?", @value)

        # in corresponds to IN, and out to NOT IN
        when 'in', 'out'
          sql_operator = (operator == 'in' ? 'IN' : 'NOT IN')
          placeholders = @value.map { '?' }.join(',')
          return (
            if @value.present?
              model.where("#{attribute} #{sql_operator} (#{placeholders})", *@value)
            elsif operator == 'in'
              model.where('1 = 0')
            else
              model.where({})
            end
          )

        # match is more-or-less LIKE
        when 'match'
          pattern = "%#{@value.gsub(/([%_!])/, '!\1')}%"
          return model.where("#{attribute} LIKE ? ESCAPE '!'", pattern)

        # range is exactly BETWEEN
        when 'range'
          min, max = @value.sort
          return model.where("#{attribute} BETWEEN ? AND ?", min, max)

        # Invalid operator?
        else
          raise "unknown operator '#{operator}'"
        end
      end

      # Filter the given +collection+, a Ruby Enumerable.
      # Internal collection-specific implementation of the +apply+ method; see
      # +apply+ for more information on this method.
      def apply_on_collection(collection) #:nodoc:
        # Nothing to filter in an empty collection
        return collection if collection.empty?

        # Assuming all objects are similar, how is *attribute* accessed? And do
        # we need to cast/convert *value* before the comparison?
        # Once known, keep the access and conversion methods as lambdas to make
        # attribute access as fast as possible.
        attr_get  = ViewScopes.generate_getter(collection.first, @attribute)
        raise "no way to get '#{@attribute}' out of collection items" unless attr_get

        value     = (@value.is_a?(Enumerable) ? @value.first : @value)
        attr_cast = ViewScopes.generate_cast(value, attr_get.(collection.first))
        raise "no way to convert '#{value}' to '#{@attribute}' values" unless attr_cast

        case (operator = @operator.to_s)
        # Standard comparison operators are just invoked directly (send
        # method) to each item against @value.
        when '==', '!=', '>', '>=', '<', '<='
          value = attr_cast.(@value)
          return collection.select do |item|
            attr_get.(item).send(operator, value) rescue nil
          end

        # in and out naturally correspond to the include? method
        when 'in', 'out'
          method = (operator == 'in' ? :select : :reject)
          values = @value.map(&attr_cast)
          return collection.send(method) do |item|
            values.include?(attr_get.(item)) rescue nil
          end

        # match is a case-insensitive in
        when 'match'
          value = @value.to_s.downcase
          return collection.select do |item|
            attr_get.(item).to_s.downcase.include?(value) rescue nil
          end

        # range corresponds to min <= value <= max
        when 'range'
          min, max = @value.map(&attr_cast).sort
          return collection.select do |item|
            attr = attr_get.(item)
            (min <= attr && attr <= max) rescue nil
          end

        # Invalid operator?
        else
          raise "unknown operator '#{operator}'"
        end
      end
    end

    # Represents a single sorting/ordering rule to apply on an ActiveRecord
    # model or Ruby collection (Enumerable). This class provides basic
    # ascending/descending ordering, and just like Scope::Filter, is also
    # intended to be used as a base class for more specialized sorting/ordering
    # rules.
    #
    # To subclass Order, the following methods will most likely need to be
    # re-implemented in the subclass to match the specialized ordering rule's
    # needs, as their behavior is specific to this simple ordering rule:
    # - +self.type_name+
    # - +apply+
    # - +valid?+
    # - +self.from_hash+
    # - +to_hash+
    # - +self.compact_hash+
    # Note that subclasses need to make sure their generated hash
    # representations have the correct +type+ (+t+) key, or +from_hash+ wont
    # be able to recreate the right object.
    class Order
      # Name of the collection/model attribute to order/sort the
      # collection/model with, as a string or symbol. Must be present as an
      # attribute on in collection/model elements and correspond to a comparable
      # value (anything that supports <, >), or no sorting/ordering will be
      # performed on the collection/model at all.
      #
      # Note that it can also be an attribute on the matching association
      # element if an association is specified.
      attr_accessor :attribute

      # SQL-like direction in which to perform the sorting/ordering; either
      # +asc+ to sort in ascending order (1, 2, 3, ...) or +desc+ to sort in
      # descending order (7, 6, 5, ...).
      # Defaults to ascending order (asc).
      attr_accessor :direction

      # Optional ActiveRecord model to join on to the filtered model before
      # filtering, to allow for *attribute* to refer to attributes on the
      # joined model.
      #
      # Almost identical to Filter's own *association* attribute; see Filter's
      # *association* attribute for more information.
      attr_accessor :association

      # Short type name for this type of specialized ordering rule.
      # This method has the same role as Filter's type_name method; it is
      # expected to be implemented in subclasses to determine which subclass
      # to load when creating an Order instance using +from_hash+
      # See Filter's +type_name+ for more information.
      def self.type_name
        nil
      end

      # Order the given +collection+ (an ActiveRecord model or a Ruby
      # Enumerable) by *attribute* in *direction*.
      # Returns a sorted/ordered version of +collection+.
      #
      # Note that if the ordering rule is invalid (no *attribute* or
      # *direction*), an exception will be thrown.
      def apply(collection)
        raise "no direction to sort in" unless @direction
        raise "no attribute to sort on" unless @attribute

        if (collection <= ActiveRecord::Base rescue nil)
          apply_on_model(collection)
        else
          apply_on_collection(collection)
        end
      end

      # Check if this Order object is valid and able to sort/order a collection
      # or model; an Order is valid if it has a sorting *direction* and
      # *attribute*.
      def valid?
        return @direction && @attribute
      end

      # Create a new Order described by the contents of +hash+. Works similarly
      # to Filter's +from_hash+ method, as each recognized pair in +hash+
      # corresponds to an Order attribute and is expected to match the
      # attribute's format, bar for +type+.
      #
      # The following keys are recognized in +hash+:
      #
      # [+type+ or +t+]
      #  Type (subclass) of Filter to create from +hash+, as a string or symbol.
      #  Handled the same way as Filter's own +type+ key; see Filter's
      #  +from_hash+ method.
      #
      # [+attribute+ or +a+]
      #  *attribute* attribute: a symbol or string.
      #
      # [+direction+ or +d+]
      #  *direction* attribute: either +asc+ or +desc+ (defaults to +asc+).
      #
      # [+association+ or +j+]
      #  *association* attribute: an ActiveRecord model or an array with an
      #  ActiveRecord model and the two attributes to perform the join with.
      #  Handled the same way as Filter's own +association+ key; see Filter's
      #  +from_hash+ method.
      #
      # Returns the newly created Order (just like new would)
      def self.from_hash(hash)
        # Make sure +hash+ is proper
        return nil unless hash.is_a?(Hash)

        hash = hash.with_indifferent_access unless
          hash.is_a?(HashWithIndifferentAccess)

        order = self.new

        # Handle Order subclasses (type key)
        if type = (hash['type'] || hash['t'])
          subclass = self.descendants.find { |sub| sub.type_name == type }
          return subclass && subclass.respond_to?(:from_hash) ?
            subclass.from_hash(hash) : order
        end

        # *attribute* must be alphanumeric (word-like)
        attribute = (hash['attribute'] || hash['a']).to_s.gsub(/[^\w.]/, '')
        order.attribute = attribute unless attribute.blank?

        # *direction* must be either ascending or descending
        direction   = (hash['direction'] || hash['d'] || 'asc').to_s.downcase
        order.direction = direction if [ 'asc', 'desc' ].include?(direction)

        # *association* must be an ActiveRecord model or an array with the
        # correct format
        order.association = ViewScopes.parse_assoc(hash['association'] || hash['j'])

        order
      end

      # Convert this Order object into a hash, doing the exact opposite of
      # +from_hash+. This method behaves almost identically to Scope's +to_hash+
      # method (and has the same argument +compact+), except for being applied
      # to a Order object instead of a Scope.
      #
      # See Scope's +to_hash+ method for further information.
      def to_hash(compact: false)
        hash = {
          'attribute'   => @attribute.to_s,
          'direction'   => @direction.to_s,
          'association' => ViewScopes.assoc_with_table(@association)
        }

        compact ? self.class.compact_hash(hash) : hash
      end

      # Compact +hash+, which is expected to be a Ruby hash matching
      # +from_hash+'s structure. Behaves similarly to Scope's +compact_hash+
      # method, except for being applied to a Order hash representation instead
      # of a Scope one.
      #
      # Note that if +hash+ contains a +type+ (or +t+) key and a valid subclass
      # exists, this method will invoke the subclass' own +compact_hash+ (if it
      # exists) to compact +hash+.
      def self.compact_hash(hash)
        return nil unless hash.is_a?(Hash)

        # Handle Order subclasses (type key)
        if type = (hash['type'] || hash[:type] || hash['t'] || hash[:t])
          subclass = self.descendants.find { |sub| sub.type_name == type }
          return subclass.compact_hash(hash) if
            subclass && subclass.respond_to?(:compact_hash)
        end

        Scope.generic_compact_hash(
          hash,
          {
            'type'        => 't',
            'attribute'   => 'a',
            'direction'   => 'd',
            'association' => 'j'
          },
          defaults: { 'direction' => 'asc' }
        )
      end

      private

      # Sort/order the given ActiveRecord +model+.
      # Internal model-specific implementation of the +apply+ method; see
      # +apply+ for more information on this method.
      def apply_on_model(model) #:nodoc:
        # Resolve and validate *attribute* as an attribute of +model+ (or
        # *association*).
        attribute, model = ViewScopes.resolve_model_attribute(@attribute, model, @association)

        raise "unknown direction '#{@direction}'" unless
          [ 'asc', 'desc' ].include?(@direction.to_s)

        model.order("#{attribute} #{@direction.to_s.upcase}")
      end

      # Sort/order the given Ruby +collection+.
      # Internal collection-specific implementation of the +apply+ method; see
      # +apply+ for more information on this method.
      def apply_on_collection(collection) #:nodoc:
        # Nothing to sort in an empty collection.
        return collection if collection.empty?

        # Assuming all objects are similar, how is *attribute* accessed?
        # Once known, keep the access method as a lambda to make attribute
        # access as fast as possible.
        attr_get = ViewScopes.generate_getter(collection.first, @attribute)
        raise "no way to get '#{@attribute}' out of collection items" unless attr_get

        collection = collection.sort_by(&attr_get)
        collection.reverse! if @direction.to_s == 'desc'
        collection
      end
    end

    # Represents a pagination component, used to paginate the given collection
    # (Ruby Enumerable) or ActiveRecord model. This class behaves as a wrapper
    # around will_paginate to handle most of the heavy work (since most Scope
    # users expect will_paginate collections).
    class Pagination
      # Page number to scope the collection/model to. For example, a collection
      # of 1000 items paginated with 100 elements per page would be scoped to
      # items 101-200 for *page* 2.
      # Defaults to 1.
      attr_accessor :page

      # Limit (number) of items per collection/model page. For example a
      # collection of 1050 items with 100 elements per page would result in a
      # paginated collection of 11 pages, 10 with 100 elements each and one with
      # only 50. Defaults to will_paginate's default of 30.
      attr_accessor :per_page

      # Optional total number of items in the collection/model, for when the
      # collection/model's entry count differs from what should be used when
      # paginating the collection/model.
      # Naturally defaults to the size of the collection/model.
      attr_accessor :total

      # Paginate +collection+, (an ActiveRecord model or a Ruby Enumerable)
      # with *per_page* elements per page, and return the paginated collection
      # scoped to the page corresponding to *page*.
      def apply(collection)
        collection = collection.to_a unless
          (collection <= ActiveRecord::Base rescue nil)

        # Clamp @page and @per_page to a sane range
        page     = [1,  [@page.to_i,     99_999].min].max
        per_page = [25, [@per_page.to_i, 1000  ].min].max

        # Is there a native paginate method available?
        if collection.respond_to?(:paginate)
          collection.paginate(
            :page          => page,
            :per_page      => per_page,
            :total_entries => @total
          )

        # Otherwise, just manually create a WillPaginate::Collection
        else
          total = @total || collection.length

          WillPaginate::Collection.create(page, per_page, total) do |pager|
            pager.replace(collection[pager.offset, pager.per_page].to_a)
          end
        end
      end

      # Create a new Pagination object described by the contents of +hash+. Just
      # like Scope's +from_hash+ method, each recognized pair in +hash+
      # corresponds to a Pagination attribute and is expected to match the
      # attribute's format.
      #
      # The following keys are recognized in +hash+:
      #
      # [+page+ or +i+]
      #  *page* attribute: an integer.
      #
      # [+per_page+ or +p+]
      #  *per_page* attribute: an integer.
      #
      # [+total+ or +t+]
      #  *total* attribute: an integer.
      #
      # Returns the newly created Pagination (just like new would)
      def self.from_hash(hash)
        return nil unless hash.is_a?(Hash)

        hash = hash.with_indifferent_access unless
          hash.is_a?(HashWithIndifferentAccess)

        pagination = self.new
        pagination.page     = Integer(hash['i'] || hash['page'] || 1) rescue nil
        pagination.per_page = Integer(hash['p'] || hash['per_page'])  rescue nil
        pagination.total    = Integer(hash['t'] || hash['total'])     rescue nil
        pagination
      end

      # Convert this Pagination object into a hash, doing the exact opposite of
      # +from_hash+. This method behaves almost identically to Scope's +to_hash+
      # method (and has the same argument +compact+), except for being applied
      # to a Pagination object instead of a Scope.
      #
      # See Scope's +to_hash+ method for further information.
      def to_hash(compact: false)
        hash = {
          'page'     => (@page.to_i     if @page),
          'per_page' => (@per_page.to_i if @per_page),
          'total'    => (@total.to_i    if @total)
        }

        compact ? self.class.compact_hash(hash) : hash
      end

      # Compact +hash+, which is expected to be a Ruby hash matching
      # +from_hash+'s structure. Behaves similarly to Scope's +compact_hash+
      # method, except for being applied to a Order hash representation instead
      # of a Scope one.
      def self.compact_hash(hash)
        Scope.generic_compact_hash(
          hash,
          {
            'page'     => 'i',
            'per_page' => 'p',
            'total'    => 't'
          },
          defaults: { 'page' => 1 }
        )
      end
    end

    # Utility methods for Scope components (Filter, Order and Pagination)

    # Compact +hash+, an hash representation of a Scope component.
    # This method is intended only as a generic way to implement a component's
    # +compact_hash+ method.
    #
    # +keys+ is expected to be a mapping of +hash+'s keys to shorter
    # versions of the same keys:
    #   {
    #     'attribute' => 'a',
    #     'operator'  => 'o',
    #     'value'     => 'v'
    #   }
    #
    # +values+, if given, is expected to be a list of +hash+ values to
    # shorten in the following format:
    #   [
    #     [<key>, <long value>, <short value>],
    #
    #     # hash['operator'] would become 'r' if it was 'range'
    #     ['operator',  'range',     'r'],
    #
    #     # hash['direction'] would become 'asc' if it was 'ascending'
    #     ['direction', 'ascending', 'asc'],
    #   ]
    #
    # +defaults+, if given, is expected to be a mapping of default values
    # for +hash+ which should be removed when compacting:
    #   {
    #     # 'asc' is the default for 'direction', and doesn't need to be included
    #     # in the compacted hash version
    #     'direction' => 'asc'
    #   }
    def self.generic_compact_hash(hash, keys, values: {}, defaults: {})
      # Make sure +hash+ is proper
      return nil unless hash.is_a?(Hash)

      compact = hash.stringify_keys.to_h

      hash = hash.with_indifferent_access unless
        hash.is_a?(HashWithIndifferentAccess)

      # Shorten attribute values
      values.each do |key, long, short|
        compact[key] = short if compact[key] == long
      end

      # Delete empty/default values
      compact.delete_if { |key, value| value.blank? }
      defaults.each do |key, value|
        compact.delete(key) if compact[key] == value
      end

      # Compact attribute keys
      keys.each do |long, short|
        compact[short] = compact.delete(long) if compact.has_key?(long)
      end

      compact
    end

  end

  # Create a new Scope from the hash-based session scope definition named +name+
  # stored in Rails' session object (+scopes+ key), invoking Scope's
  # +from_hash+ method to create the Scope instance. If +name+ is not present in
  # the session, an empty Scope is created instead. +name+ defaults to the
  # default scope name; +default_scope_name+.
  def scope_from_session(name = nil)
    name   ||= default_scope_name
    scopes   = (current_session['scopes'] ||= {})
    hash     = (scopes[name] ||= {})

    Scope.from_hash(hash).tap { |s| s.name = name }
  end

  # Store a +scope+ under the name +name+ in compact hash form in Rails' session
  # object (+scopes+ key), invoking the scope's +to_hash+ method to convert
  # to Scope instance to a hash. If +name+ is already present in the session's
  # scopes, the old scope is replaced by +scope+. +name+ defaults to the scope's
  # *name* attribute or (if unset) to the default scope name
  # (+default_scope_name+).
  def scope_to_session(scope, name = nil)
    name   ||= scope.name || default_scope_name
    scopes   = (current_session['scopes'] ||= {})
    scopes[name] = scope.to_hash(compact: true)
  end

  # Default scope name for the current route. Typically '<controller>#<route>'.
  # For example, to fetch the default scope from Rails' session explicitly:
  #   @scope = scope_from_session(default_scope_name)
  def default_scope_name
    "#{params[:controller]}##{params[:action]}"
  end

  # Update the hash-based scope definitions stored in Rails' session (under the
  # +scopes+ key) using scope-specific query parameters.
  # This method, called just before any action (as a before_filter), allows
  # updating the session's view scopes just before the control is handed to the
  # controller.
  #
  # The following query parameters are recognized by +update_session_scopes+:
  #
  # [_scopes]
  #  Expected to be a hash of changes to be merged in the session's scopes as
  #  specified by CbrainSession's +apply_changes+ method.
  #
  # [_default_scope]
  #  Expected to be a hash to be merged in the current route's default scope
  #  (current_session['scopes'][+default_scope_name+]). Behaves similarly to
  #  +_scopes+, as it too uses CbrainSession's +apply_changes+ method.
  #
  # [_scope_mode]
  #  Merging mode to employ when merging into session scopes using +_scopes+ or
  #  +_default_scope+. Corresponds to the mode parameter of CbrainSession's
  #  +apply_changes+ method. Defaults to 'replace'.
  #
  # [page, per-page/per_page]
  #  Common pagination parameters to update the scope named _pag_scope_name
  #  with. These parameters correspond to the *page* and *per_page* attributes
  #  of Scope::Pagination, and are handled purely for convenience and
  #  convention; the same functionality (and more) can be accessed by
  #  passing a hash to the +_scopes+ parameter instead.
  #
  # [_pag_scope_name]
  #  Name of the scope to update with the page and per-page/per_page parameters.
  #  Defaults to the current route's default scope name (+default_scope_name+).
  #
  # [_simple_filters]
  #  Special flag to indicate that the remaining query parameters are to be
  #  interpreted as simple attribute => value filters (each corresponding to a
  #  { :a => <attribute>, :v => <value>, :o => '==' } Scope::Filter).
  #  This simplified interface is meant to be used when manually composing URLs
  #  without aid from the Scope API (such as in applications outside CBRAIN
  #  or when composing by hand). For example, an URL to filter userfiles on a
  #  certain data provider could look like:
  #    http://portal.cbrain.ca/userfiles?_simple_filters=1&data_provider_id=4
  #  instead of the full version required by the +_scopes+ parameter.
  #
  #  To specify which scope to update, have +_simple_filters+'s value be the
  #  name of the target scope. If such a scope is not found (+_simple_filters+
  #  is '1' or 'true', for example), +update_session_scopes+ will fall back
  #  to the controller's name (common convention for index pages) then to
  #  +default_scope_name+. For example, doing:
  #    http://portal.cbrain.ca/userfiles?_simple_filters=tasks&...
  #  would update the 'tasks' scope, if it exists, while:
  #    http://portal.cbrain.ca/userfiles?_simple_filters=1&...
  #  would try to update the 'userfiles' scope, falling back to
  #  +default_scope_name+ if there is no 'userfiles' scope.
  #
  #  Note that this option cannot be used in conjunction with +_scopes+ or
  #  +_default_scope+, and that every query parameter (other than
  #  +_simple_filters+, +_scope_mode+ and pagination parameters) is considered
  #  to be a filter.
  #
  # Note that the scopes in +_default_scope+ and +_scopes+ can be in
  # compressed format (see the +compress_scope+ and +decompress_scope+ utility
  # methods).
  def update_session_scopes
    mode   = params['_scope_mode'].to_sym if
        [ 'append', 'delete', 'replace' ].include?(params['_scope_mode'])
    mode ||= :replace

    # Special _simple_filters filter syntax
    if (simple = params['_simple_filters'])
      # Determine which scope to update
      known      = (current_session['scopes'] ||= {})
      controller = params[:controller].to_s.downcase
      name   = simple     if known.has_key?(simple)
      name ||= controller if known.has_key?(controller)
      name ||= default_scope_name

      # Then convert other query parameters to Scope::Filter hashes
      excluded = [
        'action', 'controller',
        '_simple_filters', '_scope_mode',
        'page', 'per-page', 'per_page'
      ]
      scopes   = { name => { 'f' =>
        params.to_h
          .reject { |key| excluded.include?(key) }
          .map    { |attr,value| { 'a' => attr.to_s, 'v' => value.to_s } }
      } }

    # Generic scopes updates through '_scopes' or '_default_scope'
    elsif params['_scopes'] || params['_default_scope']
      # Merge _scopes and _default_scope
      scopes = (params['_scopes'] || {}).deep_dup
      scopes.merge!({ default_scope_name => params['_default_scope'] }) if
        params['_default_scope']

      # Then decompress, if required
      scopes = scopes.map do |n, s|
        return [n, s] if s.is_a?(Hash)
        [ n, ViewScopes.decompress_scope(s) ]
      end.to_h

    # No scopes updates requested
    else
      scopes = nil
    end

    # Apply the scope changes, if any
    current_session.apply_changes([mode, { 'scopes' => scopes }]) unless scopes.blank?

    # Pagination parameters (which override _scopes, _default_scope
    # and _simple_filters)
    pagination = {}
    pagination['i'] = params['page']     if params['page']
    pagination['p'] = params['per-page'] if params['per-page']
    pagination['p'] = params['per_page'] if params['per_page']
    pag_scope = params['_pag_scope_name'] || default_scope_name

    # FIXME: the per_page parameter is often passed in many requests where it
    # doesn't belong, creating spurious Scopes in the session. A workaround is
    # to require the target scope to already exist:
    pagination.delete('p') unless
      (current_session['scopes'] || {}).has_key?(pag_scope)

    current_session.apply_changes(
      { 'scopes' => { pag_scope => { 'p' => pagination } } }
    ) unless
      pagination.empty?
  end

  # Utility/helper methods

  # Add a +filter+ (a Filter instance or a hash representation) to a given
  # +scope+ (a Scope instance) with a value taken from the request parameter
  # +param+. Unless +unique+ is specified to be false, other filters in +scope+
  # acting on the same attribute will be removed before adding the new filter.
  #
  # Intended to be a simpler/quicker way to do:
  #   if (value = params[param])
  #     scope.filters << Scope::Filter.from_hash({
  #       :attribute => 'field',
  #       :value     => value
  #     })
  #   end
  def scope_filter_from_params(scope, param, filter, unique: true)
    return unless params[param]

    filter = Scope::Filter.from_hash(filter) unless filter.is_a?(Scope::Filter)
    filter.value = params[param]

    scope.filters.reject! { |f| f.attribute.to_s == filter.attribute } if
      unique && filter.attribute

    scope.filters << filter
  end

  # Add a default Order instance to a +scope+ (a Scope instance) with the
  # specified +attribute+ and +direction+ if it doesn't have any yet. This
  # method is intended as a simpler/quicker way to set a default sorting order
  # on a scope.
  def scope_default_order(scope, attribute, direction = :asc)
    return unless scope.order.blank?

    scope.order << Scope::Order.from_hash({
      :attribute => attribute,
      :direction => direction
    })
  end

  # Internal methods

  # Compress +scope+, which is expected to be a hash representation of a Scope,
  # into a string intended to be embedded in a URL. The +decompress_scope+
  # method can be used to convert the string back into a hash representation.
  # Note that if +scope+ is a string, it will be returned unchanged (to allow
  # trying to compress an already compressed scope).
  # Returns the compressed string.
  def self.compress_scope(scope)
    return scope if scope.is_a?(String)

    scope = scope.deep_dup.to_yaml
    scope = ActiveSupport::Gzip.compress(scope)
    scope = Base64.encode64(scope)
    scope
      .tr('+/',  '-_')
      .gsub(/=+$/, '')
      .gsub(/\s/,  '')
  end

  # Decompress +scope+, which is expected to be a scope string compressed by
  # +compress_scope+, into the original hash representation that was passed to
  # +compress_scope+ when compressing.
  # Note that if +scope+ is a hash, it will be returned unchanged (to allow
  # trying to decompress an already decompressed scope).
  # Returns the scope's hash representation.
  def self.decompress_scope(scope)
    return scope if scope.is_a?(Hash)

    scope.tr!('-_', '+/')
    scope = Base64.decode64(scope)
    scope = ActiveSupport::Gzip.decompress(scope)
    scope = YAML.safe_load(scope, [Date, Time, DateTime])
    scope
  end

  # Generate a getter function (lambda) to directly get the value of +attribute+
  # inside +item+. This method is mainly intended for when +item+ is a sample
  # of a large collection and a way to quickly get the value corresponding to
  # +attribute+ of each item in the collection is required (for example in
  # +Scope+::+Filter+ and +Scope+::+Order+'s +apply+ methods).
  # Returns a getter lambda, or nil if no way has been found to fetch
  # +attribute+ from +item+.
  def self.generate_getter(item, attribute)
    # item responds directly to attribute
    return lambda { |item| item.send(attribute) } if
      item.respond_to?(attribute.to_s)

    # item is hash-like, and attribute is a key
    if item.is_a?(Hash)
      return lambda { |item| item[attribute] } if
        item.has_key?(attribute)

      string = attribute.to_s
      return lambda { |item| item[string] } if
        item.has_key?(string)

      symbol = string.to_sym
      return lambda { |item| item[symbol] } if
        item.has_key?(symbol)
    end

    # item is array-like, and attribute is an index
    if item.is_a?(Array)
      index = Integer(attribute) rescue nil
      return lambda { |item| item[index] } if
        index && item.length > index
    end

    # item is not a hash, but still seems to accept keys
    return lambda { |item| item[attribute] } if
      item.respond_to?(:[])

    # No idea how to access attribute
    return nil
  end

  # Generate a cast/conversion function (lambda), to try and convert a value
  # of +from+'s type to a value of +to+'s type, for comparison purposes. This
  # method, just like +generate_getter+, is mainly intended for when +from+
  # is a sample of a large collection and a way to quickly convert to the
  # collection's type is required (for example in +Scope+::+Filter+'s +apply+
  # method).
  # Note that +from+ and +to+ are expected to be scalars (number, bool, string,
  # symbol, etc.), not compound values (array, hash, object, set, etc.).
  # Returns a cast/conversion lambda, or nil if its not possible to convert
  # +from+ to +to+.
  def self.generate_cast(from, to)
    # Same type already? Nil? Nothing to do.
    return lambda { |v| v } if from.is_a?(to.class) || from.nil? || to.nil?

    case to
    # to_s (and to_sym) for String-like types
    when String     then lambda { |v| v.to_s        }
    when Symbol     then lambda { |v| v.to_s.to_sym }

    # Straight conversions for numeric types
    when Integer    then lambda { |v| Integer(v) }
    when Float      then lambda { |v| Float(v)   }
    when Numeric    then lambda { |v| v.to_f     }

    # Match against known true/false representations for boolean types
    when TrueClass  then lambda { |v| v.to_s =~ /^(true|t|yes|y|on|1)$/i  }
    when FalseClass then lambda { |v| v.to_s =~ /^(false|f|no|n|off|0)$/i }

    else nil
    end
  end

  # Parse an association (+assoc+) coming from a hash in the context of
  # a +from_hash+ method. The association is expected to be in the same
  # format as +Scope+::+Filter+'s *association* attribute: either the
  # ActiveRecord model itself, a table name, or an array with the model and two
  # attributes name to perform the association join with
  # (see +Scope+::+Filter+'s *association* attribute and +from_hash+ method for
  # more information).
  def self.parse_assoc(assoc)
    assoc, assoc_attr, model_attr = assoc
    return nil if assoc.blank?

    # Convert a table name into an ActiveRecord model class
    unless (assoc <= ActiveRecord::Base rescue nil)
      table = assoc.to_s.tableize
      assoc = ActiveRecord::Base.descendants.find do |m|
        assoc == m.name || table == m.table_name
      end
    end

    # Clean out join attribute names
    assoc_attr = assoc_attr.to_s.gsub(/[^\w]/, '')
    model_attr = model_attr.to_s.gsub(/[^\w]/, '')

    return assoc if assoc_attr.blank? || model_attr.blank?
    [ assoc, assoc_attr, model_attr ]
  end

  # Create a new association identical to +assoc+ (same format as
  # +parse_assoc+) but using a table name (as a string) instead of an
  # ActiveRecord model class.
  def self.assoc_with_table(assoc)
    return assoc.table_name if (assoc <= ActiveRecord::Base rescue nil)
    return assoc unless assoc.is_a?(Enumerable)

    assoc, assoc_attr, model_attr = assoc
    [ assoc.table_name, assoc_attr, model_attr ]
  end

  # Join an association (+assoc+) to a +model+, validating all column and
  # table names. +model+ is expected to be an ActiveRecord model and
  # +assoc+ is expected to be a model or array in the same format as
  # +parse_assoc+'s +assoc+ parameter or +Scope+::+Filter+'s *association*
  # attribute (see +Scope+::+Filter+'s *association* attribute and +from_hash+
  # method for more information).
  #
  # Returns an array containing +model+ joined to +assoc+ and +assoc+'s model
  # class.
  def self.join_assoc(model, assoc)
    # Re-parse the association to ensure its validity
    assoc, assoc_attr, model_attr = self.parse_assoc(assoc)
    return [ model, nil ] unless assoc

    # No join columns? There should be a relation with a similar name on
    # the model.
    return [ model.joins(assoc.table_name.singularize.to_sym), assoc ] if
      assoc_attr.blank? || model_attr.blank?

    # Joins columns are specified? Validate them first before joining.
    raise "unknown association column #{assoc_attr}" unless
      assoc.attribute_names.include?(assoc_attr)

    raise "unknown model column #{model_attr}" unless
      model.attribute_names.include?(model_attr)

    # Quote attributes and tables to avoid any nasty surprises
    assoc_attr  = assoc.connection.quote_column_name(assoc_attr)
    assoc_table = assoc.quoted_table_name
    model_attr  = model.connection.quote_column_name(model_attr)
    model_table = model.quoted_table_name

    return [ model.joins(
      "INNER JOIN #{assoc_table} ON " \
      "(#{assoc_table}.#{assoc_attr} = #{model_table}.#{model_attr})"
    ), assoc ]
  end

  # Resolve +attribute+ as an attribute of +model+ joined by +association+
  # (if supplied). In order, +resolve_model_attribute+ joins +association+
  # to +model+ (if +association+ is valid) then validates that +attribute+
  # is effectively an attribute of +model+ or +association+, throwing an
  # exception otherwise.
  # This internal method is intended as a safe and generic way to fetch
  # +attribute+ from +model+ (and +association+).
  # Returns a pair; the fully qualified and quoted attribute name (quoted
  # table + column name) and +model+.
  def self.resolve_model_attribute(attribute, model, association)
    columns = { model.table_name => model.attribute_names }

    # Join up the association's model, if required
    model, assoc = self.join_assoc(model, association)
    columns[assoc.table_name] = assoc.attribute_names if assoc

    # Make sure @attribute is a valid column name, or a valid column and
    # table name.
    column, table = attribute.to_s.split('.').reverse
    table ||= model.table_name

    raise "unknown table #{table}" unless
      columns[table]
    raise "unknown column #{table}.#{column}" unless
      columns[table].include?(column)

    # Quote both the table name and column name to avoid issues with
    # special characters (spaces, for example).
    column = model.connection.quote_column_name(column)
    table  = model.connection.quote_table_name(table)

    [ "#{table}.#{column}", model ]
  end

end
