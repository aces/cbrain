# Methods added to this helper will be available to all templates in the application.

require 'time'

module ApplicationHelper

  Revision_info="$Id$"

  def title(page_title)
    content_for(:title)  { ' - ' + page_title}
  end

  def to_localtime(stringtime)
     Time.parse(stringtime).localtime.strftime("%Y-%m-%d %H:%M:%S")
  end

end
