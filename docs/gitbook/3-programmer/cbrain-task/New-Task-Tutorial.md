This document is a step by step example of how to create a new
CbrainTask in CBRAIN.

Although the task has a very basic function (computing a checksum),
the example still uses many different features of CBRAIN's framework
to illustrate them. These features include task version support,
input fields, task form refresh, data provenance logging and static
assets.

## Prerequisites

To run this tutorial, you need to install and configure a local,
personal copy of a CBRAIN BrainPortal Rails application, make sure
it is working in 'development' mode, and install and configure a
Bourreau Rails application. The instructions on how to do this are
provided in the [Setup Guide](../../1-setup/Setup-Guide.html).

## What the task does

We create a task to run a UNIX checksum program on a file. The exact
command that we run is the old, classic "cksum" program. It is
installed by default on both Linux and Mac OS operating systems and
works the same way on both.

However, to make the example more interesting and show some of
CBRAIN's capabilities, the following additional features are included:

* Multiple 'versions' of the program are supported (even though there is actually only one version
  of 'cksum'), each with their own special incompatible parameters. This shows that a CbrainTask
  can encapsulate multiple versions of a scientific tool.
* The output of 'cksum' is saved in a report, which is a plain text file, back into the CBRAIN
  user's file manager.
* Meta data about the task and the files is stored.
* Provenance information is logged (for instance, which file was used or created by which task).
* A rich user interface validates the input that the user provides.

## Running the generator

There are about a dozen files that are created and installed for
this single example of a CbrainTask. Although these files can be
created manually at the correct locations in the CBRAIN source tree,
it is better to run the [Rails CbrainTask Generator](Rails-CbrainTask-Generator.html), which creates
templates for most of them:

```bash
cd /path/to/BrainPortal
rails generate cbrain_task my_cksum
rake cbrain:plugins:clean:all
rake cbrain:plugins:install:all
```

The files that are created contain information about the kind of
code they should contain, but in this tutorial we will ignore this
and only show the minimum amount of code necessary to accomplish
our goals.

If you rename the task's files, or even just the directory where
they are contained, remember to rerun the two rake tasks listed
above. This is necessary to adjust the symbolic links that configure
the task as 'installed'.

## Editing the portal-side model

After you run the generator above, you should now have a file called
'.../MyCksum/portal/my_cksum.rb'.  Let's add the methods needed to
implement its web interface within the body of the class.

#### The default params

A task has a params hash where its parameters are stored. We can
provide a default value for all the params by creating a class
method named 'default_launch_args'.

```ruby
    def self.default_launch_args
      {
        # all params are strings if they are shown in the web page
        :output_file_prefix  => "ck_",
        :an_odd_number       => "7",    # shows in form if we run version 2.0.0 or greater
        :struct_with_day_and_month => {
          :day   => 3,
          :month => 'Jan',
        }
      }
    end
```

Note that the input file(s) on which we run the cksum program are
not stored there.  We have only created three parameters:

* :output_file_prefix is a prefix added to the filenames of the output reports.
* :an_odd_number is a number that must be odd and is only needed with version 2.0.0
  of cksum (this is necessary to configure versions 1.0.0 and 2.0.0 of the task).
* :struct_with_day_and_month is exactly what it is named and shows that arbitrary structures
  can be stored in the params, which are referred to in the task's form.

#### Pretty names for the parameters

Whenever we edit or create a new task, we have the option of adding
a "pretty name" to any parameter that appears on the web page. It
is used when Rails presents a validation error message. Pretty names
are provided by a method returning a hash with the names. The keys
are encoded using the Rails convention for parameters; for instance,
compare this to the default_launch_args() above and see how we
represent the :struct_with_day_and_month.

```ruby
    def self.pretty_params_names
      {
        :output_file_prefix                => 'prefix for the reports',
        :an_odd_number                     => 'odd number',
        "struct_with_day_and_month[day]"   => "day of month",
        "struct_with_day_and_month[month]" => "month name",
      }
    end
```

#### before_form()

This is the main callback method that most programmers want to fill.
It is invoked before the form is rendered and shown to the user
(thus the method's name). This can be used to validate the list of
files that the user has selected. In our example, we simply make
sure that all the files are "SingleFile"s (i.e. that they are simple
files, not directories, which are instead registered as subclasses
of "FileCollection").

```ruby
    def before_form
      ids = self.params[:interface_userfile_ids].presence || [] # an array of IDs
      numfound = SingleFile.where(:id => ids).count # ActiveRecord makes sure the subclasses match
      cb_error "All selected files must be simple files." if numfound != ids.size
      return "" # all ok
    end
```

The method can optionally return a string with a message (which
does not prevent the form from rendering, but the message itself
is shown). In our example, the empty string is returned, which means
everything is okay.

#### refresh_form()

We allow the user to perform several cycles of refreshing the form.
Control returns to the model by way of the refresh_form() method,
where the month name is reset to a random month.  This illustrates
a particular capability of the framework, though it may be not very
useful for simple tasks.

```ruby
    def refresh_form
      random_month = [ 'Jan', 'Feb', 'Mar', 'Apr' ].sample
      self.params[:struct_with_day_and_month][:month] = random_month
      ""  # all OK
    end
```

This refresh mechanism is invoked whenever the user clicks on a
"submit" button that contains the keyword "refresh" (case insensitive)
in its label. These types of buttons are not normally shown in the
CBRAIN task interface, but here one is added once the view partials
are written (see below).

#### after_form()

This method is invoked after the user clicks the "Submit Task"
button at the bottom of the form.

This is the perfect time to make sure all parameters for the task
are appropriate and valid. Validation of parameters can be performed
in the same way as the validation of ActiveRecord attributes, with
callbacks to custom validation methods, but it can also be performed
at this point. If a parameter has a wrong value, adding an error
message to the special error handler for params called params_errors()
prevents the task from being submitted and the form is shown again
to the user to allow him to fix the problem.

In our example, we make sure that the number entered in the input
field for the parameter :an_odd_number is really an odd number. You
can check that this validation occurs correctly by entering an even
number and making sure that the form returns with the field highlighted
in red.

Note that, as a demonstration of how code can be made conditional
on a particular version of a tool, this validation is made only if
the version of 'cksum' is at least "2.0.0" (later, two dummy versions,
1.0.0 and 2.0.0, are configured as an example - see below).

```ruby
    def after_form
      return "" unless self.tool_config.is_at_least_version("2.0.0")
      odd_num = params[:an_odd_number].presence
      if odd_num.blank? || (odd_num.to_i % 2 != 1)
        params_errors.add(:an_odd_number, "is not odd, please enter an odd number.")
      end
      params_error.add(:output_file_prefix, "must be a simple prefix with no spaces") unless
          params[:output_file_prefix] =~ /^\w+$/
      "" # all ok
    end
```

For more information about the validation and error mechanism
provided by CBRAIN for parameters, see the description for the class
CbrainTaskFormBuilder (in the CBRAIN code documentation).

#### final_task_list()

Once a task's parameters have been submitted, the programmer can
use the information to launch not just one task, but an entire array
of similar tasks. This is the method that returns an array of the
real tasks that are launched.

Invoked on the task object, it should return an array of clones (or
in fact, duplicates) of the object, differing in one or a few
parameters. The default behavior is a method in PortalTask that
returns simply an array with a single element, the object itself,
which means that normally no arrays of tasks are ever created.

For our example, however, a new task is created for each input file
selected by the user; each of the new task objects is identical to
the original task object, except the list of Userfile IDs contains
a single ID. If the user selects 50 files, the end result is to
create 50 distinct tasks.

```ruby
    def final_task_list
      ids = self.params[:interface_userfile_ids]
      tasklist = []
      ids.each do |id|
         newtask = self.dup  # duplicate the whole task
         newtask.params[:interface_userfile_ids] = [ id ] # replace the list by a new one with a single ID
         tasklist << newtask
      end
      tasklist
    end
```

## Editing the common model

The file '.../MyCksum/common/my_cksum.rb' is a place where you can
put code that is common to both the BrainPortal side and Bourreau
side of CBRAIN. In our example, we simply create a version comparison
class method. This method makes it possible to invoke some methods on the
task's 'tool_config' association, and to quickly check if the
particular version of the task selected by the user has support for
a particular feature. In our example, we pretend that if we are
runnning version "1.0.0" of CkSum, we do not need the odd number
in the params page and if we are running version "2.0.0" we need
it.

```ruby
    def self.compare_versions(v1,v2)
      v1.to_s <=> v2.to_s  # very dummy: we just compare the strings
    end
```

A proper implementation for a real task would, of course, compare
the version strings based on the conventions used by the tool's
developer (e.g. "1.2.3", "A123", or "17.4-gamma").

## Creating the view files

We have two view files to create; these are pretty standard Rails partials.

#### _task_params.html.erb

This partial contains the body of the form where the task's parameters
are entered. While writing it, we have access to @task to represent
the task object, @tool_config to represent the tool version selected
by the user and 'form' which is the Rails form handler for the
object.

We do not create input elements for the basic attributes of the
ActiveRecord CbrainTask, but instead for the parameters of the task,
which are stored as a hash table 'params' (however, this is a true
real attribute of CbrainTask). To help design the form, Cbrain
provides a set of helper methods to create the input elements. See
the class CbrainTaskFormBuilder for more information.

```erb
    <%= stylesheet_link_tag @task.public_path("cksum.css").to_s, :media => "all" %>
    <%= form.params_label      :output_file_prefix, "Output file prefix:" %>
    <%= form.params_text_field :output_file_prefix %>
    <p>
    <% if @tool_config.is_at_least_version('2.0.0') %>
       <%= form.params_label      :an_odd_number, "An odd number please:" %>
       <%= form.params_text_field :an_odd_number %>
       <p>
    <% end %>
    <div class="cksum_fancy">
    Day:   <%= form.params_text_field "struct_with_day_and_month[day]" %><br>
    Month: <%= form.params_text_field "struct_with_day_and_month[month]" %><br>
    <%= submit_tag 'Refresh The Month' %>
    </div>
```

Note that this view code demonstrates several other special features
of the CBRAIN framework:

* It shows how to refer to some static assets that the task parameter page needs (in
  our example, a stylesheet which is used to style the div element at the bottom).
* It shows how to make part of the form appear or disappear depending on
  the version of the tool that was selected by the user. This is why the method
  compare_version() was needed in common.rb, as configured above.
* A special submit button is added that adds the ability to refresh the form and get a
  new month to be populated in the params automatically via the refresh_form() method.

#### _show_params.html.erb

Normally, this file is used to show the user a summary of the
parameters for the task, once it has been created. In our example,
it just echoes back all the values in a very simple manner, including
a link to the input file, and a link to the output report (which
is stored as an ID by the Bourreau side, as will be shown later).

```erb
    Input: <%= link_to_userfile_if_accessible params[:interface_userfile_ids][0] %><br>
    Output prefix: <%= params[:output_file_prefix] %><br>
    <% if @tool_config.is_at_least_version('2.0.0') %>
      Odd number: <%= params[:an_odd_number] %><br>
    <% end %>
    Day: <%= params[:struct_with_day_and_month][:day] %><br>
    Month: <%= params[:struct_with_day_and_month][:month] %><br>
    <p>
    Output: <%= link_to_userfile_if_accessible params[:report_id] %>
```

#### The optional stylesheet

As explained above, some static assets are installed just to
demonstrate how they can be packaged with the task. In our example,
it is necessary to create a file 'cksum.css' under 'views/public',
containing this simple CSS code.

```css
    #cksum_fancy {
       border: 2px solid green;
    }
```

#### Other static assets

Two other files are created by the generator under 'views/public':

* edit_params_help.html is shown as a 'help' link above the task's
  parameter form. This is a pure static html excerpt. Simply document the
  parameters there.

* tool_info.html is shown in the "Tools Index" page, as a link called "info".
  Enter a general description of the tool on this page.

We do not edit these files in this tutorial.

## Trying the interface

At this point, we have all the code necessary to implement the
task's life cycle on the frontend.  In order to test it, though,
we have to configure it within CBRAIN.

The full documentation for creating tool versions is in [Tools](../../2-interfaces/admin_tools.html),
but for the moment we will only use the minimum code necessary to
create versions "1.0.0" and "2.0.0" of the tool.

#### Creating a Tool for CkSum

A Tool represents an application in general, irrespective of where
it is deployed and which versions exist.

* Using the CBRAIN interface as an administrator, go to the "Tools" index page.
* Click "Create new tool"
* Fill in the form; call the tool 'CkSum'; the field "CbrainTask Class" must be filled
  with "CbrainTask::MyCksum", which is the name of the Ruby class in the code.
  The other fields are not that important, except perhaps the field "Text for select box on
  the userfiles page", which should contain a message such as "Launch my CkSum".

#### Creating two ToolConfigs

A tool config represents a particular installation of a tool. We
create two versions.

* Using the CBRAIN interface as an administrator, go to the "Tools" index page.
* The 'CkSum' tool should be listed on that page - click on its name.
* The page for the 'CkSum' tool is now displayed, with a list of execution servers at the bottom and
  the message, "No specific version configured" for each one.
* Click the "Add new" link below the test execution server.
* At this point there is a new form to fill; this is the description of one particular version
  of the 'CkSum' tool.
* Enter '1.0.0' in the 'Version' field.
* Enter a short description, leave the number of CPUs to '1',  and if desired, enter environment variables or
  a bash prologue script (these are all optional).
* Save the config.
* Repeat for a second tool config with a version name called "2.0.0"; also make sure
  that this version has its number of CPUs set to "2" instead of one (this is part of
  the demonstration of automatic parallelism within CBRAIN).

#### Examining the parameters form page

Now, as any user, go to the File manager, select one or several
files, then go the the "Launch Task" menu. The launch message should
be configured above for the tool (e.g. 'Launch my CkSum'). When
prompted to choose a version, select version 1.0.0.

At that point you are sent to the task params page, and you can try
refreshing it with the refresh button, or entering invalid values
for the output name prefix. Click 'Start MyCkSum' at the very bottom,
and the task object is saved in the database in state 'New'.

Try with version "2.0.0", too, where the version-specific input
field should contain an odd number.

## Editing the Bourreau-side model

The Bourreau side is where the actual wrapping code for the tool
resides. There is only one file to edit, fortunately:
'bourreau/my_cksum.rb'. There are three methods to fill on the
Bourreau side:

* setup()
* cluster_commands()
* save_results()

#### setup()

This purpose of this method is to validate once more its parameters,
synchronize its input files, and otherwise prepare anything needed
for running the tool (like creating directories or creating symbolic links to the input files).
There are numerous helper methods available to automate many common
operations, but few of them are used here. We simply make sure that
the parameter :an_odd_number is odd if we're running version "2.0.0"
and synchronize the single input file (that is, make a copy in the
Bourreau local cache) and create a symbolic link to its data.

```ruby
    def setup
      # on the portal side, we replace this array by another one containing a single ID
      # in the method final_task_list()
      id = params[:interface_userfile_ids][0]
      # Sync file
      file = SingleFile.find(id)
      file.sync_to_cache
      # Create symlink locally, with same base name
      filename = file.name
      cached_path = file.cache_full_path
      safe_symlink(cached_path,filename) # does not mind if it already exists
      if self.tool_config.is_at_least_version('2.0.0')
        cb_error "Oh no our number isn't odd!" if (params[:an_odd_number].to_i % 2) != 1
      end
      true # must return true if all OK
    end
```

#### cluster_commands()

This is where we build a bash script to encapsulate the execution
of the tool.  In the case of the 'cksum' program, we show how CBRAIN
captures the output and error channels of the script by echoing
some words on these channels. Also the script runs 'cksum' on the
input file and sends its result to a local output file named
'PREFIXmyout-tttt-rrrr.txt', where prefix is one of the parameters,
tttt is the task's ID and rrrr is a run number, which starts at 1
and increases by 1 whenever the task is restarted. None of the other
parameters are used.

```ruby
    def cluster_commands
      id      = params[:interface_userfile_ids][0]
      file    = SingleFile.find(id)
      runid   = self.run_id # utility method, returns "#{task_id}-#{run_number}"
      prefix  = params[:output_file_prefix]
      outname = "#{prefix}myout-#{runid}.txt"
      [  # for historical reasons, this method should return an array of strings....
        "# bash script starts here",
        "echo This is standard output",
        "echo This is standard error 1>&2",
        "echo This is the report from my task > #{outname}",
        "cksum #{file.name} >> #{outname}"
      ]
    end
```

#### save_results()

This method is invoked when the task has finished on the cluster
side. Typically, the method should verify that the script has run
properly and if so then create new userfiles to store the outputs
of the tool.

Here we carry out the following steps:

* Verify that the output file from the bash script exists.
* Save its content in the database as a new TextFile.
* Log information about this processing to both the input file and the output file.
* Store the ID of the new output file in the params hash, as :report_id, so it
  shows up when looking at the web page information about the task.

```ruby
    def save_results
      id      = params[:interface_userfile_ids][0]
      infile  = SingleFile.find(id)
      runid   = self.run_id # utility method, returns "#{task_id}-#{run_number}"
      prefix  = params[:output_file_prefix]
      outname = "#{prefix}myout-#{runid}.txt"
      cb_error "Can't find my output file '#{outname}' ?!?" unless File.exists?(outname)
      outfile = safe_userfile_find_or_new(TextFile,  # utility of ClusterTask
                  { :name => outname,
                    :data_provider_id => self.results_data_provider_id.presence || infile.data_provider_id
                  }
                )
      outfile.cache_copy_from_local_file(outname) # also saves to official data provider
      outfile.move_to_child_of(infile)
      self.addlog_to_userfiles_these_created_these([infile],[outfile]) # utility of ClusterTask
      self.params[:report_id] = outfile.id  # so that the show page for the task shows it
      true
    end
```

## Trying the whole process

If you edited 'bourreau/my_cksum.rb', then it is necessary to restart
the execution server for it to be able to load the new code, even
in development mode. Make sure to run at least once the rake task
that installs the symlinks necessary for the plugin. Once that is
done, it is possible to launch the task again, as explained above.
This time, on the execution side, the bash script is run and the
output file should be added to the file manager. If something goes
wrong, inspect the content of the task's work directory and look
at all the logs provided by CBRAIN.

## Moving forward

There are many features of the CbrainTask framework that are not
covered in this tutorial:

* There is a wide set of input fields helpers, described in the class CbrainTaskFormBuilder.
* Tasks can be made to depend on other tasks, as explained in [CbrainTask Prerequisites](CbrainTask-Prerequisites.html).
* Tasks can be configured to share work directories (by default, each task is launched in a
  private work directory), as explained in [CbrainTask SharedWorkDir](CbrainTask-SharedWorkDir.html).
* Tasks can be parallelized automatically, as explained in [CbrainTask Parallelization](CbrainTask-Parallelization.html).
* Successful tasks can be configured to be restarted at different points in their life
  cycle, using special callbacks to prepare them for such events, as explained
  in [CbrainTask Recovery And Restart](CbrainTask-Recovery-and-Restart.html).
* Failed tasks can be written to allow better error recovery (including callback to
  perform cleanup), also explained in [CbrainTask Recovery And Restart](CbrainTask-Recovery-and-Restart.html).

**Note**: Original author of this document is Pierre Rioux

