
# Helper methods for tasks views.

module TasksHelper

  Revision_info=CbrainFileRevision[__FILE__]

  # Given a plain name for a task's private partial, such
  # as 'my_stuff' or :my_stuff, will return a full path
  # to the partial suitable for Rails:
  #
  #   task_partial(:my_stuff) or task_partial('my_stuff')
  #
  # will return
  #
  #   "tasks/cbrain_plugins/cbrain_task/{taskname}/views/my_stuff.html.erb"
  #
  # which will work through the symlink at the 'cbrain_plugins' level.
  # Note that the real file must start with a '_', like all partials.
  #
  # This is useful for developers of tasks that are 'plugins', they
  # don't have to know exatcly where their partial will end up on the
  # filesystem and can just use the plain name of their file in their own
  # task's 'views'.
  def task_partial(partial_name)
    plain = partial_name.to_s.sub(/^_/,"").sub(/(\.html)?(\.erb)?/i,"")
    "tasks/cbrain_plugins/cbrain_task/#{@task.name.underscore}/views/#{plain}.html.erb"
  end

  # Shows a bent-arrow character indented by +level+ 'spaces'
  # (actually, four NBSPs per level)
  def task_tree_view_icon(level)
    (('&nbsp' * 4 * level) + '&#x21b3;').html_safe
  end

  StatesToColor = {
          'Configured'                       => [ "orange",  25 ],
          'New'                              => [ "blue",    20 ],
          'Setting Up'                       => [ "blue",    30 ],
          'Queued'                           => [ "blue",    40 ],
          'On CPU'                           => [ "blue",    50 ],
          'On Hold'                          => [ "orange",  45 ],
          'Suspended'                        => [ "orange",  55 ],
          'Data Ready'                       => [ "blue",    60 ],
          'Post Processing'                  => [ "blue",    70 ],
          'Completed'                        => [ "green",   80 ],
          'Terminated'                       => [ "red",     90 ],
          'Failed'                           => [ "red",    100 ], # not an official task status, but used in reports
          'Failed To Setup'                  => [ "red",    135 ],
          'Failed On Cluster'                => [ "red",    165 ],
          'Failed To PostProcess'            => [ "red",    175 ],
          'Failed Setup Prerequisites'       => [ "red",    125 ],
          'Failed PostProcess Prerequisites' => [ "red",    165 ],
          'Recover Setup'                    => [ "purple", 220 ],
          'Recover Cluster'                  => [ "purple", 240 ],
          'Recover PostProcess'              => [ "purple", 260 ],
          'Recovering Setup'                 => [ "purple", 320 ],
          'Recovering Cluster'               => [ "purple", 340 ],
          'Recovering PostProcess'           => [ "purple", 360 ],
          'Restart Setup'                    => [ "blue",   420 ],
          'Restart Cluster'                  => [ "blue",   440 ],
          'Restart PostProcess'              => [ "blue",   460 ],
          'Restarting Setup'                 => [ "blue",   520 ],
          'Restarting Cluster'               => [ "blue",   540 ],
          'Restarting PostProcess'           => [ "blue",   560 ],
          'Preset'                           => [ "black",    0 ], # never seen in interface
          'SitePreset'                       => [ "black",    0 ], # never seen in interface
          'Duplicated'                       => [ "blue",   997 ],
          'Standby'                          => [ "orange", 998 ],
          'TOTAL'                            => [ "black",  999 ], # not an official task status, but used in reports
          'Total'                            => [ "black",  999 ]  # not an official task status, but used in reports
  }


  # Returns a HTML SPAN within which the text of the task +status+ is highlighted in color.
  def colored_status(status)
    return h(status) unless StatesToColor.has_key?(status)
    html_colorize(h(status),StatesToColor[status][0])
  end

  def cmp_status_order(status1,status2) #:nodoc:
    info1 = StatesToColor[status1] # can be nil
    info2 = StatesToColor[status2] # can be nil
    return status1 <=> status2 unless info1 && info2 # compare by name
    cmp = (info1[1] <=> info2[1]) # compare their ranks
    return cmp if cmp != 0
    status1 <=> status2 # in case of equality, compare by name again
  end

  # Returns a HTML for task Report with task, size and
  # number of unknow
  def format_task_size_unk(task,size,unk)
    
    t_s_u  = "Task: #{task}<br/>"
    t_s_u += "Size: #{pretty_size(size)}<br/>"
    t_s_u += unk.to_i > 0 ? "Unknown:  #{unk.to_i}" : "&nbsp;"
    
    return t_s_u.html_safe
  end

end

