module AccessReportHelper
  
  Revision_info=CbrainFileRevision[__FILE__]
  
  # Produces a pretty red times symbol (used to show unavailable
  # ressources)
  def red_times_icon
    "<span class=\"red_times_icon\">&times;</span>".html_safe
  end

  # Produces a pretty green o (used to show available ressources)
  def green_o_icon
    "<span class=\"green_o_icon\">&#927;</span>".html_safe
  end

  # Produces a legend for acces reports
  def access_legend
    legend  = "<center>\n"
    legend += "#{green_o_icon}: accessible "
    legend += "#{red_times_icon}: not accessible"
    legend += "</center>\n"
    return legend.html_safe
  end
  
end