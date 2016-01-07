
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

require 'json'

# Server-side component for the persistent selection component. This module
# only has one purpose; format/convert the JSON selection from the client-side
# component into a classic Ruby collection in params.
module PersistentSelection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # PersistentSelection is a simple controller extension module with just one
  # filter/handler (+merge_persistent_selection+) and no exposed methods.
  def self.included(includer) #:nodoc:
    includer.class_eval { before_filter(:merge_persistent_selection) }
  end

  # Pick out persistent selection elements (_psel_*) from the request parameters
  # and parse them out (from JSON) before merging them in params. Note that
  # selected values are expected to be unique, and that the selection elements
  # are expected to be directly in params (not nested under any other key).
  def merge_persistent_selection
    params.keys.each do |key|
      next unless key =~ /^_psel_/

      value = params.delete(key)
      value = value.first if value.is_a?(Enumerable)
      next if value.blank?

      key   = key.sub(/^_psel_/, '')
      value = JSON.parse(value)
      next unless value['bound'].is_a?(Array) && value['selection'].is_a?(Array)

      params[key] = value['selection']
        .to_set
        .subtract(value['bound'])
        .merge(params[key] || [])
        .to_a
    end
  end

end
