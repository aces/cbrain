
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

class SubclassValidator < ActiveModel::EachValidator #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def validate_each(object, attribute, value)
    superklass = object.class.sti_root_class
    root_class = superklass

    model_class = value.constantize rescue nil
    valid_types = []

    if model_class
      if options[:root_class] && Class.const_defined?(options[:root_class].to_s)
        option_root_class = options[:root_class].to_s.constantize
        root_class = option_root_class if option_root_class <= superklass
      end
      valid_types  = root_class.descendants
      valid_types << root_class
      unless options[:include_abstract_models]
        valid_types  = valid_types.reject(&:cbrain_abstract_model?).map(&:to_s)
      end
    end

    unless valid_types.include?(value)
      object.errors[attribute] << (options[:message] || " '#{value}' is not a valid subtype of #{root_class}")
    end
  end

end

