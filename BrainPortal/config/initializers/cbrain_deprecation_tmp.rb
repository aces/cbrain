
# Place holder for bad methods that need to be replaced,
# or inefficient constructs.
#
# We will remove this file in 5.0.1 once we're pretty sure none of these things
# happen anymore.

class ActiveRecord::Relation
  def blank?
    puts_red "DEPRECATED: (inefficient) .blank? called at #{caller[0]}"
    self.count == 0
  end
  def present?
    puts_red "DEPRECATED: (inefficient) .present? called at #{caller[0]}"
    self.exists?
  end
  def presence
    puts_red "DEPRECATED: (inefficient) .presence called at #{caller[0]}"
    self.exists? ? self : nil
  end
end

# These are not really deprecations; instead we try to catch the
# case where the Pathname methods return the emptiness of an existsing file or
# directory, instead of checking the path itself. It's a bug
# intriduced when Pathname decided to implement a ".empty?" method, which
# is checked by (say) .blank? .
class Pathname
  def blank?
    puts_red "DEPRECATED: (potential FS check) .blank? called at #{caller[0]}"
    self.to_s.blank?
  end
  def present?
    puts_red "DEPRECATED: (potential FS check) .present? called at #{caller[0]}"
    self.to_s.present?
  end
  def presence
    puts_red "DEPRECATED: (potential FS check) .presence called at #{caller[0]}"
    self.to_s.presence
  end
end

