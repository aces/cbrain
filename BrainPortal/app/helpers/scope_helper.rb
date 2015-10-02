
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

# Complement of the ViewScopes controller module containing view helpers to
# create, update and display Scope elements.
#
# See the ViewScopes module (lib/scope_helpers.rb) for more information on
# view scopes.
module ScopeHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Internal alias to ease access to ViewScopes::Scope and its inner classes.
  Scope = ViewScopes::Scope

  # Generate URL parameters suitable for +url_for+ to update the session scope
  # named +name+ to match +scope+ (a Scope instance or a hash representation)
  # via +update_session_scopes+. For example, to change the first filter of the
  # 'userfiles' scope:
  #   @scope = scope_from_session('userfiles')
  #   # ...
  #   new_scope = @scope.dup
  #   new_scope.filters[0].operator = '!='
  #   query_params = scope_params('userfiles', new_scope)
  # Same as above, using the hash representation of +@scope+:
  #   @scope = scope_from_session('userfiles')
  #   # ...
  #   scope_hash = @scope.to_hash
  #   scope_hash['filters'][0]['operator'] = '!='
  #   query_params = scope_params('userfiles', scope_hash)
  # Unless +compress+ is specified as false, the generated URL parameters will
  # use the compressed format as specified by +compress_scope+.
  def scope_params(name, scope, compress: true)
    scope = scope.to_hash if scope.is_a?(Scope)
    scope = Scope.compact_hash(scope)

    # Scope's compact_hash will naturally remove default values (empty arrays
    # and hashes). They are restored here to allow clearing the corresponding
    # Scope attributes, as CbrainSession's apply_changes method will only update
    # an attribute if the corresponding key is present in the input hash.
    { 'o' => [], 'f' => [], 'c' => {} }.each do |key, default|
      scope[key] = default unless scope.has_key?(key)
    end

    scope = ViewScopes.compress_scope(scope) if compress
    { '_scopes' => { name => scope } }
  end

  # Generate URL parameters suitable for +url_for+ to update the session scope
  # +scope+'s filters (via +update_session_scopes+) via a given +operation+.
  # +filters+ is expected to be Filter instances or hash representations (a
  # single filter or an Enumerable), depending on which +operation+ is to be
  # performed, and +operation+ is expected to be one of:
  # [+:add+]
  #  Add one or more +filters+ to the specified scope.
  # [+:remove+]
  #  Remove one or more +filters+ from the specified scope.
  # [+:set+]
  #  Add one or more +filters+ to the specified scope, replacing existing
  #  filters filtering on the same attributes as +filters+ (requires all filters
  #  in +filters+ to have valid *attribute* values).
  # [+:replace+]
  #  Replace all filters in the specified scope by the ones in +filters+.
  # [+:clear+]
  #  Remove all filters in the specified scope (+filters is ignored).
  #  Equivalent to using +:replace+ with an empty +filters+.
  #
  # +scope+ is expected to be either the name of a session scope to be fetched
  # using +scope_from_session+ or a Scope object with a valid *name* attribute.
  # Falls back on +default_scope_name+ if nil.
  #
  # Note that the generated URL parameters are in compressed format (see
  # +compress_scope+).
  def scope_filter_params(scope, operation, filters)
    scope = scope_from_session(scope || default_scope_name) unless
      scope.is_a?(Scope)

    filters = (filters.is_a?(Array) ? filters : [filters]).map do |filter|
      filter.is_a?(Scope::Filter) ? filter : Scope::Filter.from_hash(filter)
    end if filters

    scope_items_url_params(scope, operation, :filters, filters)
  end

  # Generate URL parameters suitable for +url_for+ to update the session scope
  # +scope+'s ordering rules (via +update_session_scopes+) via a given
  # +operation+. This method behaves just like +scope_filter_params+, but
  # operates on a Scope's ordering rules (Order instances or hash representations)
  # instead of filters. As such, the same +operation+s are available (:add,
  # :remove, :set, :replace, :clear) and the +scope+ and +orders+ parameters are
  # handled the exact same way +scope_filter_params+'s +scope+ and +filters+
  # parameters are handled.
  def scope_order_params(scope, operation, orders)
    scope = scope_from_session(scope || default_scope_name) unless
      scope.is_a?(Scope)

    orders = (orders.is_a?(Array) ? orders : [orders]).map do |order|
      order.is_a?(Scope::Order) ? order : Scope::Order.from_hash(order)
    end if orders

    scope_items_url_params(scope, operation, :order, orders)
  end

  # Generate URL parameters suitable for +url_for+ to update the session
  # +scope+ custom attributes with +custom+ (expected to be a hash of attributes
  # to merge in) using CbrainSession's +apply_changes+ method.
  #
  # +scope+ is expected to be either the name of a session scope to be fetched
  # using +scope_from_session+ or a Scope object with a valid *name* attribute.
  # Falls back on +default_scope_name+ if nil.
  #
  # Note that as with +scope_filter_params+ and +scope_order_params+, the
  # generated URL parameters are compressed using +compress_scope+.
  def scope_custom_params(scope, custom)
    name   = scope.name if scope.is_a?(Scope)
    name ||= scope || default_scope_name

    { '_scopes' => { name => ViewScopes.compress_scope({
      'c' => custom.stringify_keys
    }) } }
  end

  # Link version of +scope_params+; acts identically to +scope_params+ but
  # generates a link instead of URL parameters. All arguments but +label+ and
  # +options+ are passed directly to +scope_params+ in order to create the
  # link's URL and thus behave identically to +scope_params+'s corresponding
  # parameters.
  #
  # +label+ is expected to be the link's text label and +url+ and +link+ are
  # expected to be hashes of options to pass to url_for and link_to
  # (or ajax_link), respectively. Only the special link option :ajax (whether
  # or not to use ajax_link instead of link_to, defaulting to link_to) is not
  # passed.
  def scope_link(label, name, scope, compress: true, url: {}, link: {})
    url = url_for(scope_params(name, scope, compress: compress).merge(url))
    generic_scope_link(label, url, link)
  end

  # Link version of +scope_filter_params+. Identical to +scope_link+ but uses
  # +scope_filter_params+ in order to generate the URL. See +scope_link+ for more
  # information.
  def scope_filter_link(label, scope, operation, filters, url: {}, link: {})
    url = url_for(scope_filter_params(scope, operation, filters).merge(url))
    generic_scope_link(label, url, link)
  end

  # Link version of +scope_order_params+. Identical to +scope_link+ but uses
  # +scope_order_params+ in order to generate the URL. See +scope_link+ for more
  # information.
  def scope_order_link(label, scope, operation, orders, url: {}, link: {})
    url = url_for(scope_order_params(scope, operation, orders).merge(url))
    generic_scope_link(label, url, link)
  end

  # Link version of +scope_custom_params+. Identical to +scope_link+ but uses
  # +scope_custom_params+ in order to generate the URL. See +scope_link+ for more
  # information.
  def scope_custom_link(label, scope, custom, url: {}, link: {})
    url = url_for(scope_custom_params(scope, custom).merge(url))
    generic_scope_link(label, url, link)
  end

  # Generate a pretty string representation of +filter+, optionally using
  # +model+ (as the model +filter+ is applied to) to resolve associations
  # to names (instead of IDs). For example, a filter for +:user_id == 1+
  # could have a string representation of 'User: admin' while one for
  # +:status in ['A', 'B', 'C']+ could have 'Status: one of A, B or C'.
  #
  # Note that this method is rather inflexible on how the representations
  # are generated and relies on internal mappings for certain known
  # attributes, values and associations.
  def pretty_scope_filter(filter, model: nil)
    # UI names for certain associations.
    association_names = {
      'group'    => 'project',
      'bourreau' => 'server'
    }

    # Explanatory flag (boolean attributes) value names to use instead of
    # '<attribute>: true/1' or '<attribute>: false/0'.
    flag_names = {
      'critical'       => ['Critical', 'Not critical'],
      'read'           => ['Read',     'Unread'],
      'account_locked' => ['Locked',   'Unlocked']
    }

    # Model methods/attributes to use as representation of a model record
    naming_methods = {
      :user => :login
    }

    # In the best case, +filter+ has its own +to_s+ to generate a nice string
    # representation directly.
    return filter.to_s if filter.class.public_instance_methods(false).include?(:to_s)

    attribute = filter.attribute.to_s
    operator  = filter.operator.to_s
    values    = Array(filter.value)

    # Known flags are expected to never be association attributes, and the
    # possible values are fully represented in flag_names. If +filter+'s
    # attribute is in flag_names, the corresponding flag value name is
    # the filter's representation.
    if flag = flag_names[attribute]
      return values.first.to_s =~ /^(true|t|yes|y|on|1)$/i ? flag.first : flag.last
    end

    # Is +filter+'s attribute an association attribute? If so, resolve it
    # and use it to fetch nicer representations for +filter+'s attribute
    # and values.
    if model
      model = model.to_s.classify.constantize unless
        (model <= ActiveRecord::Base rescue nil)
      association = model.reflect_on_all_associations(:belongs_to)
        .find { |a| a.foreign_key == attribute }

      if association
        attribute = association.name.to_s
        attribute = association_names[attribute] if
          association_names[attribute]

        name_method = (
          naming_methods[association.foreign_key.to_sym] ||
          naming_methods[association.name.to_sym] ||
          :name
        )
        values.map! do |value|
          record = association.klass.find_by_id(value)
          record ? record.send(name_method) : value
        end
      end
    end

    # The type attribute has a special meaning; it usually corresponds to the
    # ActiveRecord class name.
    values.map! { |value| value.constantize.pretty_type rescue value } if
      attribute == 'type'

    # Convert the values to a textual representation, depending on which
    # operator they will be used with; single values are as-is, but
    # sets are converted to 'A, B or C' and ranges to 'A and B'.
    values = (
      if ['in', 'out'].include?(operator)
        values.map! { |v| v.to_s =~ /[,\s]/ ? "'#{v}'" : v.to_s }
        last = values.pop
        values.empty? ? last : "#{values.join(', ')} or #{last}"
      elsif operator == 'range'
        min, max = values.sort
        "#{min} and #{max}"
      else
        values.first.to_s
      end
    )

    # Have a nice textual representation of the operator
    operator = ({
      '=='    => '',
      '!='    => 'not ',
      '>'     => 'over ',
      '>='    => 'over ',
      '<'     => 'under ',
      '<='    => 'under ',
      'in'    => 'one of ',
      'out'   => 'anything except ',
      'match' => 'like ',
      'range' => 'between '
    })[filter.operator.to_s]

    "#{attribute.humanize}: #{operator}#{values}"
  end

  # Fetch the possible values (and their count) for +attribute+ within
  # +collection+, which is either a Ruby Enumerable or ActiveRecord model.
  # As this method is intended as a view helper to create the list of values to
  # filter a collection/model with, the possible values are returned as a list
  # of hashes matching +DynamicTable+'s filter format (unless +format+ is
  # specified; see below), containing:
  # [:value]
  #  Possible value for +attribute+.
  # [:label]
  #  Label (string representation) for +:value+ (or just +:value+ if
  #  unavailable).
  # [:indicator]
  #  Count of how many times this specific +:value: was found for +attribute+ in
  #  +collection+.
  #
  # This method accepts following optional (named) arguments:
  # [label]
  #  Attribute name (as a string or symbol) representing which +collection+
  #  attribute to use as value labels. Defaults to the value of +attribute+ if
  #  left unspecified.
  #
  # [association]
  #  Association to join on +collection+. Expected to be in the same format as
  #  +Scope+::+Filter+'s *association* attribute, it roughly fulfills the same
  #  purpose; allow +attribute+ and +label+ to refer to attributes on the joined
  #  model (only applicable if +collection+ is an ActiveRecord model).
  #
  #  If :association is specified and is an AR model, +attribute+ is also
  #  allowed to be nil to indicate that it should automatically be selected as
  #  the foreign key of the first association on +collection+ matching the given
  #  +association+ model. The +label+ option will also default to the 'name'
  #  attribute on the given +association+ (and will refer to the association
  #  model unless qualified by a table name). This behavior allows generating
  #  association filters without explicitly specifying the association join
  #  attributes. For example,
  #    filter_values_for(@userfiles, nil, :association => DataProvider)
  #  is equivalent to the more verbose
  #    filter_values_for(@userfiles, 'data_provider_id',
  #      :label       => 'data_providers.name',
  #      :association => DataProvider
  #    )
  #
  # [format]
  #  Lambda (or proc) accepting three arguments; a possible value for
  #  +attribute+, a label for the value, and a count of how many times this
  #  value was present. This lambda will be used to format the list of filter
  #  values, overriding the default +DynamicTable+ format specified above.
  #  Specifying +format+ is roughly equivalent to using map on the generated
  #  filter values but without having to unpack the +DynamicTable+'s filter
  #  format hash.
  #
  #  NOTE: The filters generated by this method are commonly used with the Scope
  #  and DynamicTable APIs, which impose an hidden restriction on the values
  #  that can be taken for +attribute+'s values; they must be safely
  #  deserializable from YAML. This is the case for almost all common value
  #  types with the notable exception of Symbols. If +attribute+'s values are
  #  symbols, consider converting them the resulting filter values to strings
  #  before using them to construct filtering URLs.
  def filter_values_for(collection, attribute, label: nil, association: nil, format: nil)
    return [] if collection.blank?

    # Invoke the model/collection specific method
    if (collection <= ActiveRecord::Base rescue nil)
      filters = ScopeHelper.model_filter_values(
        collection, attribute, label,
        association: association
      )
    else
      filters = ScopeHelper.collection_filter_values(
        collection, attribute, label
      )
    end

    # No need to use the default format if one is specified
    return filters.map(&format) if format

    # Format the generated filter arrays as DynamicTable's filter hashes
    filters.map do |value, label, count|
      {
        :value     => value,
        :label     => label,
        :indicator => count,
        :empty     => count == 0
      }
    end
  end

  # Fetch the possible filtering values for +attribute+ (symbol or string)
  # within +base+, viewed through +view+. +base+ is expected to be either an
  # ActiveRecord model (or scope) or Ruby Enumerable, while +view+ is expected
  # to be either the same type as +base+ or one or more Scope objects. This
  # method generates filtering values (similarly to +filter_values_for+),
  # considering +view+ as a filtered version of +base+ and counting possible
  # values in both.
  #
  # For example, if +base+ is the Userfiles model containing TextFiles, CSVFiles
  # and MincFiles and +view+ is a scope of base with just a few CSVFiles and
  # MincFiles, +scoped_filters_for+ one could have:
  #   scoped_filters_for(base, view, :type) # =>
  #   [
  #     { :value => 'TextFile', :indicator => 0, :label => '... (of 30)', ... },
  #     { :value => 'CSVFile',  :indicator => 9, :label => '... (of 10)', ... },
  #     { :value => 'MincFile', :indicator => 3, :label => '... (of 53)', ... },
  #   ]
  #
  # This method accepts the following optional (named) arguments:
  # [scope]
  #  One or more Scope objects to add on top of +view+, when +view+ isn't a
  #  collection of Scopes already.
  #
  # [label]
  #  Handled the same way as +filter_values_for+'s own +label+ parameter. Note
  #  that this includes the 'name' default if +attribute+ is nil and
  #  +association+ is specified.
  #
  # [association]
  #  Handled the same way as +filter_values_for+'s own +association+ parameter.
  #
  # [format]
  #  Lambda (or proc) to format the filter list with. Similar in behavior and
  #  handled the same way as +filter_values_for+'s own +format+ argument. The
  #  only difference between this method's +format+ and +filter_values_for+'s
  #  is a fourth argument, the possible value count under +view+.
  #  The arguments given to +format+ are thus: value, label, base count and
  #  view count.
  #
  # [strip_filters]
  #  Remove any Filter filtering on +attribute+ in all given Scope instances
  #  before applying them to +view+ (and generating filter counts). This avoids
  #  generating almost-empty filters (only a single value would have a count
  #  higher than 0). Defaults to active (true).
  #
  # Note that if Scope objects are supplied, any of their Filters filtering on
  # +attribute+ will be removed to avoid generating empty filters values unless
  # the +strip_filters+ argument is specified as false.
  #
  # Also note that this method shares +filter_values_for+'s special
  # interaction between +association+ and +attribute+; if +association+ is
  # specified and +attribute+ is nil, +attribute+ is taken as +base+'s
  # foreign key on +association+ (see +filter_values_for+'s +association+
  # parameter for more information).
  def scoped_filters_for(base, view, attribute, scope: nil, label: nil, association: nil, format: nil, strip_filters: true)
    # Handle +filter_values_for+'s special case where +attribute+ is nil and
    # corresponds to +base+'s foreign key for +association+
    attribute, label, association = ScopeHelper.find_assoc_key(base, association, label) if
      ! attribute && association

    # Normalize +attribute+ to a lower-case string, as per Scope API conventions
    attribute = attribute.to_s.downcase

    # Normalize the scopes in +view+ and +scope+ into just scopes
    scopes = scope || []
    scopes = [scopes] unless scopes.is_a?(Enumerable)

    if view.is_a?(Scope) || (view.is_a?(Enumerable) && view.all? { |v| v.is_a?(Scope) })
      scopes += Array(view)
      view = base
    end

    # Filter out +attribute+ filters, if theres any (and strip_filters
    # is enabled)
    scopes.map! do |scope|
      next scope unless scope.filters.map(&:attribute).include?(attribute)

      scope = scope.dup
      scope.filters.reject! { |f| f.attribute == attribute }

      scope
    end if strip_filters

    # Generate the base filter set, with all possible values for +attribute+ in
    # +base+
    filters = filter_values_for(
      base, attribute, label: label,
      association: association,
      format: lambda { |x| x }
    )

    # Generate another filter set under +view+ (and all given scopes), as a
    # hash (<value> => [<filter>]) and append the generated counts to each
    # value in the base filter set
    view_filters = filter_values_for(
      scopes.inject(view) { |v, s| s.apply(v) },
      attribute,
      association: association,
      format: lambda { |x| x }
    ).index_by { |f| f.first }

    filters.each { |f| f << (view_filters[f.first].last rescue 0) }

    # Use the specified +format+ if there is one
    return filters.map(&format) if format

    # Otherwise format the generated filter arrays as DynamicTable's filter
    # hashes, just like +filter_values_for+'s default format.
    filters.map do |value, label, base, view|
      {
        :value     => value,
        :label     => "#{label} (of #{base})",
        :indicator => view,
        :empty     => view == 0
      }
    end
  end

  # Fetch the possible values for an +attribute+ within a given +collection+,
  # optionally filtered under +view+. There are two ways to invoke
  # +default_filters_for+:
  #   default_filters_for(collection, attribute)
  # and:
  #   default_filters_for(collection, view, attribute)
  # depending on whether or not +view+ is set.
  # A simple wrapper around +filter_values_for+ and +scoped_filters_for+, this
  # method offers a set of commonly used defaults when generating simple
  # attribute filters.
  #
  # +collection+ and +attribute+ are passed directly to +filter_values_for+ or
  # +scoped_filters_for+, with one exception; if both +collection+ and
  # +attribute+ are AR models (or scopes), +default_filters_for+ will pass
  # +attribute+ as an association on +collection+ instead:
  #   default_filters_for(some_scope, SomeModel)
  # corresponds to:
  #   filter_values_for(scope_scope, nil, association: SomeModel)
  #
  # For more information on how filter values are generated,
  # see +filter_values_for+ and +scoped_filters_for+.
  def default_filters_for(*args)
    # Generate a formatting lambda which will call +block+ to format a filter
    # value's label.
    formatter = lambda do |block|
      return unless block

      lambda do |args|
        value, label, base, view = args
        label = block.(label) rescue label
        label = "#{label} (of #{base})" if view
        {
          :value     => value,
          :label     => label,
          :indicator => view || base,
          :empty     => (view || base) == 0
        }
      end
    end

    # Unpack args, respecting the possible ways to call +default_filters_for+
    collection = args.shift
    attribute  = args.pop
    view       = args.first

    # Pre-set some defaults
    is_assoc = attribute <= ActiveRecord::Base rescue nil
    label  = 'login' if is_assoc && attribute <= User
    format = formatter.((
      proc { |l| l.constantize.pretty_type } if
        attribute.to_s.downcase == 'type'
    )) unless is_assoc

    # Invoke +filter_values_for+ or +scoped_filters_for+ to generate the actual
    # filters, depending or whether or not a scope/view has been specified.
    filters = (
      if view || @scope
        scoped_filters_for(
          collection, (view || collection), (attribute unless is_assoc),
          association: (attribute if is_assoc),
          scope:  @scope,
          label:  label,
          format: format
        )
      else
        filter_values_for(
          collection, (attribute unless is_assoc),
          association: (attribute if is_assoc),
          label:  label,
          format: format
        )
      end
    )

    # Convert all symbol values to strings to avoid deserialization issues
    # when used in scope URLs.
    filters.each { |f| f[:value] = f[:value].to_s if f[:value].is_a?(Symbol) }
    filters
  end

  # Internal methods

  # Generate URL parameters suitable for +url_for+ to update the session +scope+
  # items (ordering or filtering rules). This method is the internal
  # implementation of +scope_filter_params+ (and +scope_order_params+).
  # - +operation+ corresponds exactly to +scope_filter_params+'s +operation+
  # parameter.
  # - +scope+ is a Scope object corresponding to +scope_filter_params+'s +scope+
  # parameter.
  # - +attr+ is expected to be either :filters, to update scope filtering rules,
  # or :order, for ordering rules. It corresponds to the Scope attribute name
  # to apply +changes+ on.
  # - +changes+ corresponds to +scope_filter_params+'s +changes+ parameter, and
  # is expected to be an array of filter objects (Scope::Filter) or ordering
  # rules (Scope::Order).
  #
  # Note that unlike most other utility methods, this method is exclusively
  # intended to be used only to implement +scope_filter_params+ and
  # +scope_order_params+ and is most likely unsuitable for anything else.
  def scope_items_url_params(scope, operation, attr, changes) #:nodoc:
    return {} unless changes.present? || [:clear, :replace].include?(operation)

    key   = (attr == :filters ? 'f' : 'o')
    items = (
      case operation
      when :set
        replaced = changes.map { |c| c.attribute }
        changes + scope.send(attr).reject { |c| replaced.include?(c.attribute) }
      when :clear
        []
      else
        changes
      end
    )

    mode = (
      case operation
      when :add    then :append
      when :remove then :delete
      else :replace
      end
    )

    {
      '_scope_mode' => mode,
      '_scopes' => {
        scope.name => ViewScopes.compress_scope({
          key => items.map { |i| i.to_hash(compact: true) }
        })
      }
    }
  end

  # Generate a link to +url+ with label +label+. Paper-thin wrapper around
  # link_to and ajax_link intended for scope_*_link methods, this method just
  # passes +label+, +url+ and +options+ to one of the two based on +options+'s
  # :ajax key (only key which is not passed down).
  def generic_scope_link(label, url, options)
    return link_to(label, url, options) unless options.delete(:ajax)

    ajax_link(label, url, options.reverse_merge({
      :class    => 'action_link',
      :datatype => :script
    }))
  end

  # Fetch the possible values (and their count) for +attribute+ within +model+,
  # an ActiveRecord model. Internal model-specific implementation of
  # +filter_values_for+ for AR models; see +filter_values_for+ for more
  # information on this method's arguments.
  #
  # Note that the filter values returned by this method are in array format,
  # ([value, label, count]) as this method is intended for internal use by
  # +filter_values_for+ which will perform final formatting.
  def self.model_filter_values(model, attribute, label, association: nil)
    # Handle the special case where +attribute+ is nil and corresponds to
    # +model+'s foreign key for +association+
    attribute, label, association = ScopeHelper.find_assoc_key(base, association, label) if
      ! attribute && association

    # Resolve and validate the main +attribute+ to fetch the values of
    attribute, model = ViewScopes.resolve_model_attribute(attribute, model, association)

    # And +label+, if provided
    if label
      label, model = ViewScopes.resolve_model_attribute(label, model, association)
    else
      label = attribute
    end

    # NOTE: The 'AS' specifier bypasses Rails' uniq on column names, which
    # would remove the label column if +label+ happens to have the same value
    # as +attribute+.
    label_alias = model.connection.quote_column_name('label')

    # Fetch the main filter values as an array of arrays:
    # [[value, label, count], [...]]
    model
      .where("#{attribute} IS NOT NULL")
      .order(label, attribute)
      .group(attribute, label)
      .raw_rows(attribute, "#{label} AS #{label_alias}", "COUNT(#{attribute})")
      .reject { |r| r.first.blank? }
      .map(&:to_a)
      .to_a
  end

  # Fetch the possible values (and their count) for +attribute+ within
  # +collection+, a generic Ruby collection. Internal collection-specific
  # implementation of +filter_values_for+ for Ruby collections; see
  # +filter_values_for+ for more information on this method's arguments.
  #
  # Note that the filter values returned by this method are in array format,
  # ([value, label, count]) as this method is intended for internal use by
  # +filter_values_for+ which will perform final formatting.
  def self.collection_filter_values(collection, attribute, label)
    # Make sure +attribute+ and +label+ can be accessed in
    # +collection+'s items.
    attr_get = ViewScopes.generate_getter(collection.first, attribute)
    raise "no way to get '#{attribute}' out of collection items" unless attr_get

    if label && label != attribute
      lbl_get = ViewScopes.generate_getter(collection.first, label)
      raise "no way to get '#{label}' out of collection items" unless lbl_get
    else
      lbl_get = attr_get
    end

    # Generate the main filter values as an array of arrays:
    # [[value, label, count], [...]]
    collection
      .map     { |i| [attr_get.(i), lbl_get.(i)].freeze }
      .reject  { |v, l| v.blank? }
      .sort_by { |v, l| l }
      .inject(Hash.new(0)) { |h, i| h[i] += 1; h }
      .map     { |(v, l), c| [v, l, c] }
  end

  # Find the first association/relation on +model+ matching +association+,
  # if it exists, and return, as an array;
  # - The foreign key between +model+ and +association+,
  # - A qualified +label+ column name for the association (defaults to 'name'),
  # - A fully qualified association specification (assoc and join columns)
  # This array format directly corresponds to +scoped_filters_for+ and
  # +filter_values_for+'s attribute, label and association parameters.
  #
  # Internal method to implement +scoped_filters_for+ and +filter_values_for+'s
  # special +attribute+-is-nil handling.
  def self.find_assoc_key(model, association, label = nil)
    # Find the matching +association+ reflection on +model+
    association = association.klass if association.respond_to?(:klass)
    reflection  = model
      .reflect_on_all_associations
      .find { |r| r.klass == association }
    raise "no associations on '#{model.table_name}' matching '#{association.table_name}'" unless
      reflection

    [
      reflection.foreign_key,
      "#{reflection.table_name}.#{label || 'name'}",
      [
        association,
        reflection.association_primary_key,
        reflection.association_foreign_key
      ]
    ]
  end

  # Deprecated/old methods

  # Generate +count+ as a link to +controller+'s index page, with +filters+ as
  # the only filters applied on +controller+'s scope. +count+ is expected to be
  # a count (Integer) of some sort (usually a count of elements on one end of
  # an association), :controller a controller name as a symbol or string, and
  # +filters+ a set of old-style filters (hash of <attribute> => <value> pairs,
  # each equivalent to a { :a => <attribute>, :v => <value>, :o => '==' }
  # Filter).
  #
  # The available options in +options+ are:
  # [:show_zeros]
  #  By default, +index_count_filter+ will return an empty string if +count+
  #  is 0. If this option is specified, '0' will be returned instead.
  # [:scope_name]
  #  Scope name to update with the generated link. Defaults to +controller+,
  #  the same as the controller name.
  #
  # This method more-or-less behaves as a clunky, if sightly less wordy,
  # alternative to using scope_filter_link (:replace operation) directly with
  # a few quirks added.
  def index_count_filter(count, controller, filters, options = {})
    return (options[:show_zeros] ? '0' : '') if (count = count.to_i) == 0

    controller = controller.to_s.downcase
    controller = 'bourreaux' if controller == 'remote_resources'

    scope_filter_link(count,
      (options[:scope_name] || controller),
      :replace, filters.map do |attr, value|
        { :a => attr, :v => value }
      end,
      url: { :controller => controller }
    )
  end

end
