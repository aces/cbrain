
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# Runs static ruby code in text form. Admin only.
#
# The options has should contain the following entries:
#
#   :prepare_items     => 'ruby code to prepare items'
#   :before_first_item => 'ruby code to run before the first item is processed'
#   :after_last_item   => 'ruby code to run after the last item is processed'
#   :process_item      => 'ruby code to process one item'
#
# Although these keys look similar to the names to some of the methods of the
# framework, the values are not the methods, but just pure ruby text invoked
# by the respective the methods.
#
# The code will be executed by, respectively, the actual methods
# prepare_dynamic_items(), before_first_item(), after_last_item() and
# process(item).
#
# In all case, the code's binding will be the current BackgroundActivity
# object, and in the case of process_item(), the item itself will be in
# the closure.
#
# Example of an options hash: this create a BAC that computes the square of the numbers
# listed in the items list, but only if the item is even.
#
#    bac.options = {
#      :prepare_items => 'self.items = [1,2,3,4]',
#      :process_item  =>  'return [ true, item*item ] if item % 2 == 0;return [ false, "Is Odd" ]'
#    }
class BackgroundActivity::RubyRunner < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_dynamic_bac_presence_of_option :process_item

  def prepare_dynamic_items
    code = options[:prepare_items].to_s.presence
    return if code.blank?
    eval code
  end

  def process(item)
    code = options[:process_item].to_s.presence
    return self.internal_error! if code.blank?
    eval code
  end

  def before_first_item
    if ! self.user.has_role?(:admin_user)
      raise "Not admin user" # marks as internal error
    end
    code = options[:before_first_item].to_s.presence
    return if code.blank?
    eval code
  end

  def after_last_item
    code = options[:after_last_item].to_s.presence
    return if code.blank?
    eval code
  end

end

