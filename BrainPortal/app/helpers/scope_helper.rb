
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
      'match' => '~',
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
  # [scope]
  #  Generate a separate set of filter value counts (how many times a given
  #  filter value is found) for +collection+ when scoped under +scope+. For
  #  example, if a given userfile collection has 30 TextFiles out of 40 and
  #  10 of those 30 belong to a given user, the unscoped TextFile filter count
  #  would be 30 and the user-scoped count 10. When this option is specified,
  #  +format+ takes a fourth argument; the corresponding scoped count, and,
  #  if +format+ is unspecified, the two counts (normal and scoped) are appended
  #  to the default label value. For example, in the above TextFile example,
  #  the label would look like 'TextFile (10/30)'.
  #
  #  Note that any Filter filtering on +attribute+ in +scope+ will be skipped to
  #  avoid generating empty filter values (while this behavior is
  #  counter-intuitive and clunky, it is required for table filtering).
  def filter_values_for(collection, attribute, label: nil, association: nil, format: nil, scope: nil)
    return [] if collection.blank?

    # Remove any +attribute+ filter on +scope+
    if scope
      scope = scope.dup
      scope.filters.reject! do |f|
        f.attribute.to_s.downcase == attribute.to_s.downcase
      end
    end

    # Invoke the model/collection specific method
    if (collection <= ActiveRecord::Base rescue nil)
      filters = model_filter_values(
        collection, attribute, label,
        association: association,
        scope: scope
      )
    else
      filters = collection_filter_values(
        collection, attribute, label,
        scope: scope
      )
    end

    # No need to use the default format if one is specified
    return filters.map(&format) if format

    # Format the generated filter arrays as DynamicTable's filter hashes
    filters.map do |value, label, count, *rest|
      scoped = rest.first
      label  = "#{label} (#{scoped}/#{count})" if scoped
      {
        :value     => value,
        :label     => label,
        :indicator => scoped || count,
        :empty     => (scoped || count) == 0
      }
    end
  end

  # Fetch the possible values for +attribute+ within +collection+.
  # A simple wrapper around +filter_values_for+, this method offers a set
  # of commonly used defaults to +filter_values_for+ when generating simple
  # attribute filters.
  #
  # +collection+ and +attribute+ are passed directly to +filter_values_for+,
  # with one exception; if both +collection+ and +attribute+ are AR models
  # (or scopes), +default_filters_for+ will pass +attribute+ as an association
  # on +collection+ instead:
  #   default_filters_for(some_scope, SomeModel)
  # corresponds to:
  #   filter_values_for(scope_scope, nil, association: SomeModel)
  #
  # For more information on how filter values are generated,
  # see +filter_values_for+.
  def default_filters_for(collection, attribute)
    # Generate a formatting lambda which will call +block+ to format a filter
    # value's label.
    formatter = lambda do |block|
      return unless block

      lambda do |args|
        value, label, count, scoped = args
        label = block.(label) rescue label
        label = "#{label} (#{scoped}/#{count})" if scoped
        {
          :value     => value,
          :label     => label,
          :indicator => scoped || count,
          :empty     => (scoped || count) == 0
        }
      end
    end

    # Is +attribute+ an association?
    if (attribute <= ActiveRecord::Base rescue nil)
      filter_values_for(collection, nil, association: attribute,
        scope: @scope,
        label: ('login' if attribute <= User)
      )
    else
      filter_values_for(collection, attribute,
        scope:  @scope,
        format: formatter.((
          proc { |l| l.constantize.pretty_type } if
            attribute.to_s.downcase == 'type'
        ))
      )
    end
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
  # information on this method's arguments (which are handled just like
  # +filter_values_for+'s, save for +scope+).
  #
  # Note that the filter values returned by this method are in array format,
  # ([value, label, count, (scoped_count)]) as this method is intended for
  # internal use by +filter_values_for+ which will perform final formatting.
  def model_filter_values(model, attribute, label, association: nil, scope: nil)
    # Handle the special case where +attribute+ is nil and corresponds to
    # +model+'s foreign key for +association+
    if ! attribute && association
      # Find the matching +association+ reflection on +model+
      assoc = association.respond_to?(:klass) ? association.klass : association
      reflection = model
        .reflect_on_all_associations
        .find { |r| r.klass == assoc }
      raise "no associations on '#{model.table_name}' matching '#{assoc.table_name}'" unless
        reflection

      # Use +association+'s reflection to set missing argument values
      attribute   = reflection.foreign_key
      label       = "#{reflection.table_name}.#{label || 'name'}"
      association = [
        assoc,
        reflection.association_primary_key,
        reflection.association_foreign_key
      ]
    end

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
    filters = model
      .where("#{attribute} IS NOT NULL")
      .order(attribute, label)
      .group(attribute, label)
      .raw_rows(attribute, "#{label} AS #{label_alias}", "COUNT(#{attribute})")
      .reject { |r| r.first.blank? }
      .map(&:to_a)
      .to_a

    # No +scope+? Then +filters+ is ready
    return filters unless scope

    # Add in the scoped counts
    scoped = scope.apply(model)
      .where("#{attribute} IS NOT NULL")
      .group(attribute)
      .raw_rows(attribute, "COUNT(#{attribute})")
      .to_h

    filters.map { |f| f << (scoped[f.first] || 0) }
  end

  # Fetch the possible values (and their count) for +attribute+ within
  # +collection+, a generic Ruby collection. Internal collection-specific
  # implementation of +filter_values_for+ for Ruby collections; see
  # +filter_values_for+ for more information on this method's arguments
  # (which are handled just like +filter_values_for+'s, save for +scope+).
  #
  # Note that the filter values returned by this method are in array format,
  # ([value, label, count, (scoped_count)]) as this method is intended for
  # internal use by +filter_values_for+ which will perform final formatting.
  def collection_filter_values(collection, attribute, label, scope: nil)
    # Make sure +attribute+ and +label+ can be accessed in
    # +collection+'s items.
    attr_get = ViewScopes.generate_getter(collection.first, attribute)
    raise "no way to get '#{attribute}' out of collection items" unless attr_get

    if label == attribute
      lbl_get = attr_get
    else
      lbl_get = ViewScopes.generate_getter(collection.first, label || attribute)
      raise "no way to get '#{label}' out of collection items" unless lbl_get
    end

    # Generate the main filter values as a hash; [value, label] => count
    count_values = lambda do |collection|
      collection
        .map     { |i| [attr_get.(i), lbl_get.(i)].freeze }
        .reject  { |v, l| v.blank? }
        .sort_by { |v, l| v }
        .inject(Hash.new(0)) { |h, i| h[i] += 1; h }
    end

    filters = count_values.(collection)

    # Add in the scoped counts, if required, then flatten the hash into
    # array format
    if scope
      scoped = count_values.(scope.apply(collection))
      filters.map { |i, c| [*i, c, scoped[i] || 0] }
    else
      filters.map { |(v, l), c| [v, l, c] }
    end
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
