CBRAIN comes with a Rails generator to help programmers create new
CbrainTasks. The generator will create templates for all the files
and directories for a new task, already filled with explanations
and placeholder methods.

## Usage

The generator is invoked like any other Rails generator, with:

```bash
    rails generate cbrain_task my_task_name
```

where "my_task_name" can be provided either in underscore format
(as shown) or in camel case format (such as "MyTaskName"). Either of these
work.

Help with using the generator can be obtained with:

```bash
    rails generate cbrain_task -h
```

## Running it

The following command can be run to create a task named 'TicketStats':

```bash
    rails generate cbrain_task ticket_stats
```

and the generator will create the following files and directories:

      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/portal
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/bourreau
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/common
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/views
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/views/public
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/portal/ticket_stats.rb
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/bourreau/ticket_stats.rb
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/common/ticket_stats.rb
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/views/_task_params.html.erb
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/views/_show_params.html.erb
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/views/public/edit_params_help.html
      create  cbrain_plugins/cbrain-plugins-local/cbrain_task/ticket_stats/views/public/tool_info.html

Notice that the generator creates its files in a 'plugins package'
hardcoded to the name of 'cbrain-plugins-local'. This directory can
be renamed to anything you want once the task's development is complete.
See the [Plugins Structure](../Plugins-Structure.html) page for more information about 'plugins packages'.

There are seven files that you can now edit. Each is pre-filled
with code excerpts and information to help you get started. For more
information about creating a CbrainTask, see the [CbrainTask Programmer Guide](CbrainTask-Programmer-Guide.html).

## Removing generated files

If for some reason you do not want to keep the files that you have
just generated (for instance, if you have not even started editing
them and would like to change the name of your task), then you can
invoke the Rails destructor:

```bash
    rails destroy cbrain_task my_task_name
```

This will erase the files and directories for the task.

**Note**: Original author of this document is Pierre Rioux