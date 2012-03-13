
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


###################################################################
# WillPaginate extensions
###################################################################

module WillPaginate
  if const_defined?(:ViewHelpers) # For will_paginate 3.0.pre2
    class ViewHelpers::LinkRenderer
      protected
      def base_url_params
        default_url_params
      end
    end
  end
  
  if const_defined?(:ActionView) # For will_paginate 3.0.3
    class ActionView::LinkRenderer
      protected
      def merge_get_params(url_params)
        url_params
      end
    end
  end
end
