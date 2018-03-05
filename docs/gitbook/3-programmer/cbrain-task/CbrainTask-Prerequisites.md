Prerequisites are properties of CBRAIN CbrainTask objects that allow
programmers to specify dependencies between tasks. It makes it
possible to specify that a task's life cycle depends on other
tasks' life cycles. This document explains how this mechanism is
implemented and how to use it. Developers need to first understand the
overall state diagram of a CbrainTask in order to fully follow this
discussion; please refer to the [CbrainTask Programmer Guide](CbrainTask-Programmer-Guide.html)
for more information about this.

## Life cycle prerequisites

The CBRAIN task objects have an attribute called 'prerequisites'. It is
structured as a hash table, although it is not important for developers to
understand this in detail since there is an API to populate it properly.
Basically, it makes it possible to configure a task such that its progress on
the cluster will depend on the progress of one or several other tasks.

To understand the possibilities offered by this feature, it is necessary
to review the life cycle of a task. There are many different states that a
task can go through, but for most purposes, we only need to describe
THREE essential ones:

  **Setting up** -> **On CPU** -> **Post processing**

* **Setting up**
  - Language: Ruby
  - Code: Method `setup()` in the Bourreau's CbrainTask
  - Performed by: BourreauWorker
  - Effect: Creating the work directory and running the setup code
  - State reached upon completion: "Queued"

* **On CPU**
  - Language: bash commands, to run scientific programs
  - Code: Supplied by the `cluster_commands()` method in the CbrainTask
  - Performed by: Cluster's computing nodes
  - Effect: Scientific processing
  - State reached upon completion: "Data ready"

* **Post processing**
  - Language: Ruby
  - Code: Method `save_results()` in the Bourreau's CbrainTask
  - Performed by: BourreauWorker
  - Effect: Saving the results back in the CBRAIN Data Providers
  - State reached upon completion: "Completed"

Note that each of these three stages has an associated state that
indicates when the stage is finished. For instance, the **Setting up**
state is finished once the **Queued** state has started. Similarly, the
**Post processing** state is finished once the **Completed** state
has started. This is important because the prerequisite system uses
these associated state names.

Now, assume there is an existing task E on the cluster and a
new task N is created. Restrictions on the progress of task N can
be imposed at two places in its life cycle:

* Task N can be blocked before it enters the **Setting up** state (i.e. it will
  stay in the **New** state).
* Task N can be blocked before it enters the **Post processing** state (i.e. it
  will stay in the **Data ready** state).

The blocking can occur based on the three completion statuses
discussed above:

* Until task E is in the **Queued** state (or later)
* Until task E is in the **Data ready** state (or later)
* Until task E is in the **Completed** state

plus one more special condition:

* Until task E is in **Failed** state (any of the failed states).

Note that the blocking of task N can happen both before the **Setting up**
state and **Post processing** state and in each case there can be multiple
other tasks involved, each specified with one of their three
completion statuses (or a **Failed** state).

## API methods

The prerequisites API works to allow you to set up these rules easily.
There are only two methods, based on the two blocking states for
your task:

* `add_prerequisites_for_setup(other_task,other_state = 'Completed')`
* `add_prerequisites_for_post_processing(other_task,other_state = 'Completed')`

## Example

Here is a complete example that you can run on the console.

```ruby
dp_id = DataProvider.first.id # adjust
tc    = ToolConfig.first      # adjust
bo_id = tc.bourreau_id
us_id = User.first.id         # adjust

# Create a new task t1; it lasts three minutes, 60 seconds in each stage
t1        = CbrainTask::Diagnostics.new(
              :user_id        => us_id,
              :bourreau_id    => bo_id,
              :tool_config_id => tc.id,
              :status         => 'New'
            )
t1.params = {
   :setup_delay => 60,
   :cluster_delay => 60,
   :postpro_delay => 60
}
t1.save # launch it

# Create a new task t2 that depends on the other one, t1:
t2        = t1.dup ; t2.status = 'New' # just to be sure
t2.params = {} # nothing special
# Let's make it so t2 can only be in setup once t1 is on CPU.
t2.add_prerequisites_for_setup(t1,'Queued')
t2.save

# Let's make t3 run right away but be blocked at its post
# processing until t1 has finished on CPU and t2 is fully finished.
t3        = t1.dup ; t3.status = 'New'
t3.params = {} # nothing special
t3.add_prerequisites_for_post_processing(t1,"Data Ready")
t3.add_prerequisites_for_post_processing(t2,"Completed")
t3.save
```

Thus there is an artificial delay at task t1, but all the other tasks execute
as fast as possible. A typical run of these three tasks, if they are all submitted
at once, would result in the following sequence of events:

* At 0 seconds:
  - t1 -> **Setting up** [60 seconds long]
  - t2 -> **New** [blocked for t1]
  - t3 -> **Setting up** -> **Queued** -> **On CPU** -> **Data ready** [blocked for t1 and t2] \(quickly\)
* At 60 seconds:
  - t1 -> **Queued** -> **On CPU** [60 seconds long]
  - t2 -> **Setting up** -> **Queued** -> **On CPU** -> **Data ready** -> **Post processing** -> **Completed**
  - t3 -> [still blocked for t1]
* At 120 seconds:
  - t1 -> **Data ready** -> **Post processing** [60 seconds long]
  - t3 -> **Post processing** -> **Completed**
* At 180 seconds:
  - t1 -> **Completed**

This system is general enough that most processing dataflows can
be implemented using it. It also has some nice features that arise since
task statuses are retrieved from a central database: a task can depend
on the state of tasks running on OTHER clusters!

**Note**: Original author of this document is Pierre Rioux.
