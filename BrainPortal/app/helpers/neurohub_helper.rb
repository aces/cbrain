
#
# CBRAIN Project
#
# Copyright (C) 2008-2020
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

# Helpers for neurohub interface
module NeurohubHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def nh_user_icon
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#user_icon"></use>
    </svg>
    SVG
  end

end
