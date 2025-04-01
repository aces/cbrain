
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

  def neighbor_file_link(neighbor, index, dir, options = {}) #:nodoc:
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

  # Generates a set of two links, one for a 'previous' file and one for a 'next' file.
  # The argument +sort_index+ is the index of the 'current' file.
  def file_link_table(previous_userfile, next_userfile, sort_index, options = {})
    return "" if sort_index.blank?
    (
    "<div class=\"display_table\" style=\"width:100%\">" +
      "<div class=\"display_row\">" +
        "<div class=\"display_cell\">#{neighbor_file_link(previous_userfile, [0, sort_index - 1].max, :previous, options.clone)}</div>" +
        "<div class=\"display_cell\" style=\"text-align:right\">#{neighbor_file_link(next_userfile, sort_index + 1, :next, options.clone)}</div>" +
      "</div>" +
    "</div>"
    ).html_safe
  end

  # Generates links to pretty file content for files inside FileCollections.
  # Generates a download link if no viewer code can be found for the files.
  def data_link(file_name, userfile, replace_div_id="sub_viewer_filecollection_cbrain")
    full_path_name  = Pathname.new(userfile.cache_full_path.dirname + file_name)

    display_name  = full_path_name.basename.to_s
    return h(display_name) unless userfile.is_locally_synced?

    file_lstat = full_path_name.lstat  # lstat doesn't follow symlinks, so we can tell if it is one

    # return if userfile class is a FileCollection and file is not a file (i.e. a directory)
    return h(display_name) if userfile.is_a?(FileCollection) && !file_lstat.file?

    matched_class   = SingleFile.descendants.unshift(SingleFile).find { |c| file_name =~ c.file_name_pattern }
    matched_class ||= userfile.class if userfile.is_a?(SingleFile)

    viewer        = matched_class.class_viewers.first.partial rescue nil

    if matched_class && viewer
      on_click_ajax_replace(
          { :url     => display_userfile_path(userfile,
                                             :file_name             => file_name,
                                             :action                => :display,
                                             :viewer                => viewer,
                                             :viewer_userfile_class => matched_class
                                             ),
            :replace => replace_div_id,
          }
        ) do
          ("<span class=\"sub_viewable_link\">"+display_name+"</span>").html_safe
      end
    else
      link_to h(display_name),
              url_for(:action  => :content, :content_loader => :collection_file, :arguments => file_name)
    end
  end

  # This intercepts the standard Rails helper for the route.
  # When userfile is a fake_record, it adds a query parameter :file_name
  # with value userfile.name. Otherwise it acts with the standard behavior
  # of the helper.
  def content_userfile_path(userfile, options={})
    return super(userfile, options.merge(:file_name => userfile.name)) if
      userfile.is_a?(Userfile) && userfile.fake_record?
    super
  end

  # The router does not provide a helper for the route userfiles#stream,
  # so this is a replacement. This helper can be used in three modes:
  #
  # With SingleFile, it will create a link using the file's name.
  #
  # With standard FileCollection, it will require a :file_path in argument which
  # must start the FileCollection's own name.
  #
  # With a fake FileCollection that already has a relative path in the name,
  # this helper can be invoked without having to provide the :file_path.
  #
  #   stream_userfile_path(myTextFile)
  #   stream_userfile_path(myFileCollection, :file_path => "my_fc/a/b.txt")
  #   stream_userfile_path(myFakeFileCollection) # name contains a file_path
  def stream_userfile_path(userfile, options={})
    options     = options.dup
    file_path   = options.delete(:file_path).presence
    file_path   = userfile.name if userfile.is_a?(SingleFile) # always
    file_path ||= userfile.name # hopefully contains a relative path
    query       = options.to_query
    path        = userfile_path(userfile) + "/stream/" + file_path
    path       += "?#{query}" if query.present?
    path.html_safe
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
