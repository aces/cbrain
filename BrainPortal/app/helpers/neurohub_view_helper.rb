
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
module NeurohubViewHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def nh_empty_files
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 239.42 187.76"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#empty_files"></use>
    </svg>
    SVG
  end

  def nh_empty_invites
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 364 188"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#empty_invites"></use>
    </svg>
    SVG
  end

  def nh_empty_projects
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 364 188"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#empty_projects"></use>
    </svg>
    SVG
  end

  def nh_empty_search
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 137.74 163.54"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#empty_search"></use>
    </svg>
    SVG
  end

  def nh_empty_storage
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 214.51 182.53"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#empty_storage"></use>
    </svg>
    SVG
  end

  def nh_empty_tasks
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 260.1 185.84"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#empty_tasks"></use>
    </svg>
    SVG
  end

  def nh_icon_caret_right
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#caret_right"></use>
    </svg>
    SVG
  end

  def nh_icon_cb_external
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#cb_external"></use>
    </svg>
    SVG
  end

  def nh_icon_cb_filled
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#cb_filled"></use>
    </svg>
    SVG
  end

  def nh_icon_cb_outline
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#cb_outline"></use>
    </svg>
    SVG
  end

  def nh_icon_edit
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#edit"></use>
    </svg>
    SVG
  end

  def nh_icon_file
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#file"></use>
    </svg>
    SVG
  end

  def nh_icon_grid
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#grid"></use>
    </svg>
    SVG
  end

  def nh_icon_list
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#list"></use>
    </svg>
    SVG
  end

  def nh_icon_project
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#project"></use>
    </svg>
    SVG
  end

  def nh_icon_search
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#search"></use>
    </svg>
    SVG
  end

  def nh_icon_task
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#task"></use>
    </svg>
    SVG
  end

  def nh_icon_user
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#user"></use>
    </svg>
    SVG
  end

  def nh_stats_filesize
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#stats_filesize"></use>
    </svg>
    SVG
  end

  def nh_stats_files
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#stats_files"></use>
    </svg>
    SVG
  end

  def nh_stats_invites
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#stats_invites"></use>
    </svg>
    SVG
  end

  def nh_stats_members
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#stats_members"></use>
    </svg>
    SVG
  end

  def nh_stats_tasks
    <<-SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
    >
      <use xlink:href="#{image_path("neurohub.svg")}#stats_tasks"></use>
    </svg>
    SVG
  end

end
