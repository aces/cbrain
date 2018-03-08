
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

# This model encapsulates a record with a precise list
# of attributes. This is not an ActiveRecord, it's a
# subclass of Hash. See RestrictedHash for more info.
# Note that the attributes are used for an ActiveResource
# request, and therefore must be filled with strings.
#
# The attributes in this particular model are used to
# encode the kind of data that a CustomFilter.
class CustomFilterData < RestrictedHash

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # List of allowed keys in the hash
  self.allowed_keys=[
    # Data available for Userfile and Task filter
    :user_id,
    :type, 
    :date_attribute, 
    :absolute_or_relative_to, 
    :absolute_or_relative_from,
    :absolute_or_relative_to,  
    :rel_date_from, 
    :rel_date_to, 
    :abs_from, 
    :abs_to, 
    :relative_from, 
    :absolute_from, 
    :relative_to, 
    :absolute_to,
    :archiving_status, 


    # Only for Userfile filter
    :size_type, 
    :size_term, 
    :file_name_type, 
    :group_id, 
    :file_name_term, 
    :description_type, 
    :parent_name_like, 
    :child_name_like, 
    :sync_status,

    # Only for Task filter 
    :data_provider_id, 
    :description_term, 
    :bourreau_id, 
    :status, 
    :wd_status, 

    # Not defined in form
    :created_date_type,
    :date_term, 
    :created_date_term, 
    :tag_ids, 
  ]

end

