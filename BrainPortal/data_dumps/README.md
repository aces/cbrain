
# CBRAIN Data Dump Subdirectory

This directory is initially empty but it's where some CBRAIN
maintenance and statistics tasks dump their files.

### BackgroundActivity Dumps (under "bacs/")

These are files named like 'loginname.jsonl'. They are
concatenations of BackgroundActivity objects in JSON format,
grouped by user, one JSON record per line. They are created
whenever a user destroy a BackgroundActivity, either
directly with the interface, or by the admin when scheduling
BackgroundActivity::EraseBackgroundActivities objects.

### ResourceUsage Dumps

These are created with the rake
task `cbrain:resource_usage:dump` and reloaded
with `cbrain:resource_usage:reload` .

Files usually appear in sets of 4, for example:

* CputimeResourceUsageForCbrainTask.2021-12-31T120856.yaml
* SpaceResourceUsageForCbrainTask.2021-12-31T120856.yaml
* SpaceResourceUsageForUserfile.2021-12-31T120856.yaml
* WalltimeResourceUsageForCbrainTask.2021-12-31T120856.yaml

By default, the `dump` task will only dump records for
resources that no longer exist.

The `reload` task requires a timestamp in argument
(e.g. `2021-12-31T120856`).

### Standard regular maintenance

On a system with a large amount of activity, a regular cleanup
of the ResourceUsage table is necessary. The process is performed
in two steps:

First dump all resource usage objects that refer to objects
no longer existing in the database, and remove them from
the database:

```
  RAILS_ENV=something rake cbrain:resource_usage:dump[DESTROY_ALL,no]
```

Second, re-insert monthly summaries of all removed records so that
total historical usage by users is maintained:

```
  RAILS_ENV=something rake cbrain:resource_usage:monthly[All]
```

Note that this last step will re-create all monthly summaries
cumulatively using the info in all previous YAML dumps. This
rake task can safely be run multiple times, it will not duplicate
summary information.

### See also

See the file [BrainPortal/lib/tasks/resource_usage_serialization.rake](https://github.com/aces/cbrain/blob/master/BrainPortal/lib/tasks/resource_usage_serialization.rake)
for more information about the rake tasks.
