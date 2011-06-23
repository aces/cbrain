
# Helper methods for tasks views.

module TasksHelper

  Revision_info="$Id$"

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
          'Duplicated'                       => "blue",
          'Standby'                          => "orange",
          'Configured'                       => "orange",
          'New'                              => "blue",
          'Setting Up'                       => "blue",
          'Queued'                           => "blue",
          'On Hold'                          => "orange",
          'On CPU'                           => "blue",
          'Suspended'                        => "orange",
          'Data Ready'                       => "blue",
          'Post Processing'                  => "blue",
          'Completed'                        => "green",
          'Terminated'                       => "red",
          'Failed To Setup'                  => "red",
          'Failed To PostProcess'            => "red",
          'Failed On Cluster'                => "red",
          'Failed Setup Prerequisites'       => "red",
          'Failed PostProcess Prerequisites' => "red",
          'Recover Setup'                    => "purple",
          'Recover Cluster'                  => "purple",
          'Recover PostProcess'              => "purple",
          'Recovering Setup'                 => "purple",
          'Recovering Cluster'               => "purple",
          'Recovering PostProcess'           => "purple",
          'Restart Setup'                    => "blue",
          'Restart Cluster'                  => "blue",
          'Restart PostProcess'              => "blue",
          'Restarting Setup'                 => "blue",
          'Restarting Cluster'               => "blue",
          'Restarting PostProcess'           => "blue",
          'Preset'                           => "black",  # never seen in interface
          'SitePreset'                       => "black",  # never seen in interface
          'Failed'                           => "red"     # not an official task status, but used in reports
  }


  # Returns a HTML SPAN within which the text of the task +status+ is highlighted in color.
  def colored_status(status)
    return status unless StatesToColor.has_key?(status)
    html_colorize(status,StatesToColor[status])
  end

end

