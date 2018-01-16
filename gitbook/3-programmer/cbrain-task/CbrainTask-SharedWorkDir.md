A developer creating a new CbrainTask can specify that it should reuse 
the work directory of another previously existing task. This could be useful 
if a scientific job is launched on a cluster and a follow-up 'cleanup' or 
'reporting' job needs to use the same temporary files and directories.

## API methods

When a new task, 'mytask', is created, its work directory can be set to be that
of an existing task, 'othertask'.  This can be done simply by setting the attribute
``:share_wd_tid`` in the new 'mytask' object to the ID of 'othertask':

```ruby
  mytask.share_wd_tid = othertask.id
```

A method can be used to set the attribute while at the same time
setting a prerequisite rule:

```ruby
   mytask.share_workdir_with(othertask)
```

Setting the prerequisite is the equivalent of calling:

```ruby
   mytask.add_prerequisites_for_setup(othertask,"Completed")
```

For more information about prerequisites, see the following document:
[CbrainTask Prerequisites](CbrainTask-Prerequisites.html).

## Example

The following code can be run on the console:

```ruby
  othertask           = CbrainTask::Diagnostics.new(
                          :user_id        => 1,
                          :tool_config_id => 1,
                          :status         => 'New',
                          :params         => {},
                        ) # adjust the IDs
  othertask.save

  mytask              = othertask.dup; mytask.status = 'New'
  mytask.share_wd_tid = othertask.id                       # Use othertask's work directory!
  mytask.add_prerequisite_for_setup(othertask,"Queued") # to prevent race conditions
  mytask.save
```

Both tasks have the same path name in their attribute ``:cluster_workdir``, 
once they have been set up. Also, their standard outputs and
errors are stored in distinct files and are not mixed up, which can be
confirmed by examining the contents of the workdir with "ls -a".

As explained in the API section above, the assignment to ``share_wd_tid``
and the prerequisites can be set in a single step by this utility method:

```ruby
  mytask.share_workdir_with(othertask,"Queued")
```

## Caveats to this approach

There are some obvious caveats to this method:

* The 'othertask' must be on the same Bourreau.

* The 'othertask' must have an ID assigned (e.g. that assigned after ``save()``).

* The 'othertask' must still have its work directory stored on
  the cluster. Tasks that are removed using the 'Remove selected task' 
  button on the interface have their work directories erased.
  Also, some cluster operators may delete the scratch disk
  space used by the task if it has been there for too long.
  If the work directory has disappeared, the 'mytask' task will not
  set up and it will fail with **"Failed To setup"**.

## Arbitrary sharing in final_task_list()

Programmers who are planning to create arrays
of tasks using the portal-side framework can
tell the framework to automatically share the
work directories of arbitrary subsets of tasks
of the array. This is performed by assigning
negative values to the ``share_wd_tid`` attributes
of the tasks that are returned by ``final_task_list()``.
The rules are simple:

* All tasks with the same negative value will share the work 
  directories of the first task with that value.

* As usual, tasks with nil values will get their own private work 
  directories.

* Tasks with positive values will use the work directory of the task 
  with that value's ID, as described above.

Here's an example. The ``final_task_list()`` method shown here will 
return five tasks, partitioned such that three work directories are used:

```ruby
  # Create five clones of the current task, each with a different description.
  # Task 0 and 3 share 0's workdir, task 1 and 4 share 1's workdir
  # and task 2 has its own private workdir.
  def final_task_list
    share_values = [ -100, -44, nil, -100, -44 ] # five aribitrary share_wd_tid values
    taskarray = 5.times.map do |i|
      cloned_t = self.clone
      cloned_t.description = "Task #{i}"
      cloned_t.share_wd_tid = share_values[i] # gets nil, or -100, or -44
      cloned_t
    end
    return taskarray # [ t1 -> -100, t2 -> -44, t3 -> nil, t4 -> -100, t5 -> -44 ]
 end
```
  
**Note**: Original author of this document is Pierre Rioux