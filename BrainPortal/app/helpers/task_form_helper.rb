
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

# Helper methods for tasks forms.
module TaskFormHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

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
  # don't have to know exactly where their partial will end up on the
  # filesystem and can just use the plain name of their file in their own
  # task's 'views'.
  def task_partial(partial_name)
    plain = partial_name.to_s.sub(/\A_/,"").sub(/(\.html)?(\.erb)?/i,"")
    "tasks/cbrain_plugins/installed-plugins/cbrain_task/#{@task.name.underscore}/views/#{plain}.html.erb"
  end

  # This method can be used to insert in a task's parameters panel
  # a fieldset element containing a single text field for a renaming pattern.
  # The pattern is a string that the task can use to build output userfile names,
  # where the pattern contain such special keywords as {task_id} etc.
  # The default list of keywords along with their description can be
  # obtained by calling output_renaming_default_dt_dd_keywords().
  #
  # The first argument must be the form object used by the task parameters,
  # which has to be an instance of the custom CbrainTaskFormBuilder.
  #
  # The second argument is the name of task's parameter for the pattern,
  # which will be passed to form.params_text_field().
  #
  # The argument extra_dt_dd_pairs is an optional set of extra descriptions of
  # special custom keywords for the pattern substitions. These descriptions will
  # end up in the fieldset below the default keywords. The format of that
  # array is an ordered set of pairs, e.g.
  #
  #   output_renaming_fieldset(form, :newname,
  #         [ [ "{author}",              "Author of the <em>book</em>".html_safe ],
  #           [ "{in-1}, {in-2} etc...", "Special components blah blah" ],
  #         ]
  #   )
  #
  # This would add two more dd/dt sections in the fieldset:
  #
  #      <dd>{author}</dd>
  #      <dt>Author of the <em>book</em></dt>
  #      <dd>{in-1}, {in-2} etc...</dd>
  #      <dt>Special components blah blah</dt>
  #
  # The options hash can contain these values:
  #
  #   :no_default_keywords   If true, none of the default keywords defined in
  #                          output_renaming_default_dt_dd_keywords() will be
  #                          included in the description section. You will HAVE
  #                          to provide at least one keyword description in
  #                          the extra_dt_dd_pairs argument.
  #
  def output_renaming_fieldset(form, param_name = :output_renaming_pattern, extra_dt_dd_pairs = [], options = {})
    dt_dd_pairs  = options[:no_default_keywords] ? [] : output_renaming_default_dt_dd_keywords()
    dt_dd_pairs += extra_dt_dd_pairs
    render :partial => 'tasks/output_renaming_fieldset', :locals => { :form => form, :param_name => :output_renaming_pattern, :dt_dd_pairs => dt_dd_pairs }
  end

  private

  # Returns a basic list of output renaming keywords with
  # their descriptions; these are by default used by
  # output_renaming_fieldset() for the description section.
  # The format of this list is described in that method.
  # The current keywords described here are:
  #
  #   "{date}"          # e.g. "2013-03-18"
  #   "{time}"          # e.g. "10:23:45"
  #   "{task_id}"       # e.g. 1528
  #   "{run_number}"    # e.g. 1
  #   "{cluster}"       # e.g. "myexecserver"
  #
  def output_renaming_default_dt_dd_keywords
    [
      [ "{date}",
        "The current date in this format: YYYY-MM-DD"
      ],

      [ "{time}",
        "The current time in this format: HH:MM:SS"
      ],

      [ "{task_id}",
        "A unique number ID for the task, which doesn't change if the task is restarted"
      ],

      [ "{run_number}",
        "A numeric run number that increases everytime the task is restarted, initially set to '1'"
      ],

      [ "{cluster}",
        "The name of the execution server"
      ],
    ]
  end

end

