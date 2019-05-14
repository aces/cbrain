class AdjustCustomFilters < ActiveRecord::Migration[5.0]

  CbrainSystemChecks.check([ :a002_ensure_Rails_can_find_itself ])

  # List of data attributes to pluralize (must be the singular)
  ATTS_TO_ADJUST = %i(
    user_id
    group_id
    type
    data_provider_id
  )
  # Note: tag_ids is UserfileCustomFilters are already OK

  PortalTask # force load of subclasses
  Userfile   # force load of subclasses

  def up
    adjust_all(:unchanged_attribute_name,      :pluralize_data_attribute_name)
  end

  def down
    adjust_all(:pluralize_data_attribute_name, :unchanged_attribute_name)
  end

  def adjust_all(from_method,to_method)
    CustomFilter.all.each do |cf|
      changed = false
      cf_data = cf.data.dup.presence || {}
      ATTS_TO_ADJUST.each do |att|
        from_att = send(from_method, att)
        to_att   = send(to_method,   att)
        vals     = cf_data.delete(from_att)
        vals     = Array(vals).map(&:presence).compact
        next unless vals.present?
        vals     = vals[0] if to_method == :unchanged_attribute_name # when singularizing, take first value of array
        puts_yellow "Changing #{cf.class}/#{cf.id} : #{from_att} -> #{to_att}"
        puts_red    "Values : #{vals.inspect}"
        cf_data[to_att] = vals
        changed = true
      end
      next unless changed
      cf.data = cf_data
      cf.save!
    end
  end

  def unchanged_attribute_name(attname)
    attname
  end

  def pluralize_data_attribute_name(singular_attame)
    singular_attame.to_s.pluralize.to_sym
  end

end
