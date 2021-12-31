
# CBRAIN Data Dump Subdirectory

This directory is initially empty
but it's where some CBRAIN maintenance
and statistics tasks dump their files.

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

See the file [BrainPortal/lib/tasks/resource_usage_serialization.rake](https://github.com/aces/cbrain/blob/master/BrainPortal/lib/tasks/resource_usage_serialization.rake)
for more information about the rake tasks.
