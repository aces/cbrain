
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

# Helper methods for Userfile views.
module UserfilesHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # For display of userfile names, including:
  # type icon (collection or file), parentage icon,
  # link to show page, sync status and formats.
  def filename_listing(userfile, link_options={})
    html = []
    html << tree_view_icon(userfile.level) if @scope.custom[:tree_sort] && userfile.level.to_i > 0
    html << link_to_userfile_if_accessible(userfile, nil, link_options)
    if userfile.hidden?
      html << " "
      html << hidden_icon
    end
    if userfile.immutable?
      html << " "
      html << immutable_icon
    end

    userfile.sync_status.each do |syncstat|
      html << render(:partial => 'userfiles/syncstatus', :locals => { :syncstat => syncstat })
    end

    html.join.html_safe
  end

  def neighbor_file_link(neighbor, index, dir, options = {})
    return "" unless neighbor

    if dir == :previous
      text   = "<< " + neighbor.name
    else
      text   = neighbor.name + " >>"
    end

    action       = params[:action] #Should be show or edit.
    link_options = options.delete(:html)

    link_to text, {:action  => action, :id  => neighbor.id, :sort_index => index}, link_options
  end

  def file_link_table(previous_userfile, next_userfile, sort_index, options = {})
    (
    "<div class=\"display_table\" style=\"width:100%\">" +
      "<div class=\"display_row\">" +
        "<div class=\"display_cell\">#{neighbor_file_link(previous_userfile, [0, sort_index - 1].max, :previous, options.clone)}</div>" +
        "<div class=\"display_cell\" style=\"text-align:right\">#{neighbor_file_link(next_userfile, sort_index + 1, :next, options.clone)}</div>" +
      "</div>" +
    "</div>"
    ).html_safe
  end

  # Generates links to pretty file content for userfiles
  # of type TextFile or ImageFile; this method is going to
  # be replaced by a proper generic framework in 4.2.0 !
  def data_link(file_name, userfile)
    display_name  = Pathname.new(file_name).basename.to_s
    return h(display_name) unless userfile.is_locally_synced?

    matched_class = SingleFile.descendants.unshift(SingleFile).find { |c| file_name =~ c.file_name_pattern }
    return h(display_name) unless matched_class

    if matched_class <= TextFile
      link_to h(display_name),
              display_userfile_path(userfile,
                :content_loader        => :collection_file,
                :arguments             => file_name,
                :viewer                => :text_file,
                :viewer_userfile_class => :TextFile,
                :content_viewer        => "off",
              ),
              :target => "_blank"
    elsif matched_class <= ImageFile
      link_to h(display_name),
              display_userfile_path(userfile,
                :content_loader        => :collection_file,
                :arguments             => file_name,
                :viewer                => :image_file,
                :viewer_userfile_class => :ImageFile,
                :content_viewer        => "off",
              ),
              :target => "_blank"
    else
       h(display_name)
    end
  end

  # Returns the HTML code that represent a symbol
  # for +statkeyword+, which is a SyncStatus 'status'
  # keyword. E.g. for "InSync", the
  # HTML returned is a green checkmark, and for
  # "Corrupted" it's a red 'x'.
  def status_html_symbol(statkeyword)
    html = case statkeyword
      when "InSync"
        '<font color="green">&#10003;</font>'
      when "ProvNewer"
        '<font color="green">&lowast;</font>'
      when "CacheNewer"
        '<font color="purple">&there4;</font>'
      when "ToCache"
        '<font color="blue">&darr;</font>'
      when "ToProvider"
        '<font color="blue">&uarr;</font>'
      when "Corrupted"
        '<font color="red">&times;</font>'
      else
        '<font color="red">?</font>'
    end
    html.html_safe
  end

  # Returned a colorized size for the userfile ; if the
  # userfile is a FileCollection, appends the number of
  # files in the collection.
  #
  #   123.4 Mb
  #   123.4 Mb (78 files)
  def colored_format_size(userfile)
    size = colored_pretty_size(userfile.size)
    size += " (#{userfile.num_files.presence || '?'} files)" if userfile.is_a?(FileCollection)
    size.html_safe
  end

end
