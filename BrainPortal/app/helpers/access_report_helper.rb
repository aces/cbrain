module AccessReportHelper
  
  Revision_info=CbrainFileRevision[__FILE__]
  
  # Produces a pretty times symbol (used to show unavailable ressources)
  def times_icon(color="red")
    "<span style=color:#{color} class=\"bold_icon\">&times;</span>".html_safe
  end

  # Produces a pretty o symbol (used to show available ressources)
  def o_icon(color="green")
    "<span style=color:#{color} class=\"bold_icon\">&#927;</span>".html_safe
  end

  # Produces a centered legend 
  def center_legend(title, legend_a)
    legend  = "<center>"
    legend += "#{title}&nbsp;&nbsp;&nbsp;&nbsp;" if title
    legend_a.each do |pair|
      symbol = pair[0]
      label  = pair[1]
      legend += "#{symbol}:&nbsp#{label}&nbsp;&nbsp;&nbsp;&nbsp;"
    end
    legend += "</center>\n"
    return legend.html_safe
  end
  
end
